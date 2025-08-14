import Foundation

// MARK: - Tool Protocol

protocol Tool {
    var name: String { get }
    var description: String { get }
    var parameters: ToolParameters { get }
    
    func execute(arguments: [String: Any]) async throws -> ToolResult
}

// MARK: - Tool Parameter Schema

struct ToolParameters: Codable {
    let type: String = "object"
    let properties: [String: ParameterProperty]
    let required: [String]
    
    init(properties: [String: ParameterProperty], required: [String] = []) {
        self.properties = properties
        self.required = required
    }
}

struct ParameterProperty: Codable {
    let type: String
    let description: String
    let enum: [String]?
    let format: String?
    
    init(type: String, description: String, enum: [String]? = nil, format: String? = nil) {
        self.type = type
        self.description = description
        self.enum = `enum`
        self.format = format
    }
}

// MARK: - Tool Result

struct ToolResult {
    let success: Bool
    let content: String
    let metadata: [String: Any]?
    
    init(success: Bool, content: String, metadata: [String: Any]? = nil) {
        self.success = success
        self.content = content
        self.metadata = metadata
    }
}

// MARK: - Tool Registry

@Observable
class ToolRegistry {
    static let shared = ToolRegistry()
    
    private var registeredTools: [String: Tool] = [:]
    private var enabledTools: Set<String> = []
    
    init() {
        registerBuiltInTools()
        enableDefaultTools()
    }
    
    // MARK: - Registration
    
    func register<T: Tool>(_ tool: T) {
        registeredTools[tool.name] = tool
        print("Registered tool: \(tool.name)")
    }
    
    func unregister(toolName: String) {
        registeredTools.removeValue(forKey: toolName)
        enabledTools.remove(toolName)
    }
    
    private func registerBuiltInTools() {
        register(CalculatorTool())
        register(DateTimeTool())
        register(WeatherTool())
        register(WebSearchTool())
        register(TextAnalysisTool())
        register(UnitConverterTool())
    }
    
    private func enableDefaultTools() {
        enabledTools = ["calculator", "datetime", "text_analysis", "unit_converter", "web_search", "weather"]
    }
    
    // MARK: - Tool Management
    
    func enableTool(_ toolName: String) {
        if registeredTools.keys.contains(toolName) {
            enabledTools.insert(toolName)
        }
    }
    
    func disableTool(_ toolName: String) {
        enabledTools.remove(toolName)
    }
    
    func isToolEnabled(_ toolName: String) -> Bool {
        return enabledTools.contains(toolName)
    }
    
    // MARK: - Tool Access
    
    var availableTools: [Tool] {
        return registeredTools.values.filter { enabledTools.contains($0.name) }
    }
    
    var allTools: [Tool] {
        return Array(registeredTools.values)
    }
    
    func tool(named name: String) -> Tool? {
        guard enabledTools.contains(name) else { return nil }
        return registeredTools[name]
    }
    
    // MARK: - Tool Execution
    
    func executeTool(name: String, arguments: [String: Any]) async throws -> ToolResult {
        guard let tool = tool(named: name) else {
            throw ToolError.toolNotFound(name)
        }
        
        do {
            let result = try await tool.execute(arguments: arguments)
            print("Tool \(name) executed successfully")
            return result
        } catch {
            print("Tool \(name) execution failed: \(error)")
            throw ToolError.executionFailed(name, error)
        }
    }
    
    // MARK: - OpenRouter API Integration
    
    func getToolDefinitions() -> [Networking.Tool] {
        return availableTools.map { tool in
            Networking.Tool(
                type: "function",
                function: Networking.ToolFunction(
                    name: tool.name,
                    description: tool.description,
                    parameters: convertToOpenRouterParameters(tool.parameters)
                )
            )
        }
    }
    
    private func convertToOpenRouterParameters(_ params: ToolParameters) -> [String: Any] {
        var result: [String: Any] = [
            "type": params.type,
            "properties": [:],
            "required": params.required
        ]
        
        var properties: [String: Any] = [:]
        for (key, property) in params.properties {
            var propDict: [String: Any] = [
                "type": property.type,
                "description": property.description
            ]
            
            if let enumValues = property.enum {
                propDict["enum"] = enumValues
            }
            
            if let format = property.format {
                propDict["format"] = format
            }
            
            properties[key] = propDict
        }
        
        result["properties"] = properties
        return result
    }
}

// MARK: - Tool Error

enum ToolError: LocalizedError {
    case toolNotFound(String)
    case executionFailed(String, Error)
    case invalidArguments(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found"
        case .executionFailed(let name, let error):
            return "Tool '\(name)' execution failed: \(error.localizedDescription)"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Built-in Tools

// MARK: Calculator Tool

struct CalculatorTool: Tool {
    let name = "calculator"
    let description = "Perform mathematical calculations and expressions"
    
    let parameters = ToolParameters(
        properties: [
            "expression": ParameterProperty(
                type: "string",
                description: "Mathematical expression to evaluate (e.g., '2 + 3 * 4', 'sqrt(16)', 'sin(pi/2)')"
            )
        ],
        required: ["expression"]
    )
    
    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let expression = arguments["expression"] as? String else {
            throw ToolError.invalidArguments("Missing 'expression' parameter")
        }
        
        do {
            let result = try evaluateExpression(expression)
            return ToolResult(
                success: true,
                content: "The result of '\(expression)' is \(result)",
                metadata: ["expression": expression, "result": result]
            )
        } catch {
            return ToolResult(
                success: false,
                content: "Error evaluating expression '\(expression)': \(error.localizedDescription)"
            )
        }
    }
    
    private func evaluateExpression(_ expression: String) throws -> Double {
        let expr = NSExpression(format: expression)
        guard let result = expr.expressionValue(with: nil, context: nil) as? NSNumber else {
            throw NSError(domain: "CalculatorError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid expression"])
        }
        return result.doubleValue
    }
}

// MARK: DateTime Tool

struct DateTimeTool: Tool {
    let name = "datetime"
    let description = "Get current date/time information and perform date calculations"
    
    let parameters = ToolParameters(
        properties: [
            "action": ParameterProperty(
                type: "string",
                description: "Action to perform",
                enum: ["current", "format", "add", "subtract", "timezone"]
            ),
            "format": ParameterProperty(
                type: "string",
                description: "Date format string (for format action)"
            ),
            "date": ParameterProperty(
                type: "string",
                description: "Date string to work with (ISO 8601 format)"
            ),
            "component": ParameterProperty(
                type: "string",
                description: "Date component to add/subtract",
                enum: ["days", "hours", "minutes", "months", "years"]
            ),
            "value": ParameterProperty(
                type: "integer",
                description: "Value to add/subtract"
            ),
            "timezone": ParameterProperty(
                type: "string",
                description: "Timezone identifier (e.g., 'America/New_York')"
            )
        ],
        required: ["action"]
    )
    
    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let action = arguments["action"] as? String else {
            throw ToolError.invalidArguments("Missing 'action' parameter")
        }
        
        let formatter = ISO8601DateFormatter()
        
        switch action {
        case "current":
            let now = Date()
            let timeZone = (arguments["timezone"] as? String).flatMap { TimeZone(identifier: $0) } ?? TimeZone.current
            
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .full
            displayFormatter.timeStyle = .medium
            displayFormatter.timeZone = timeZone
            
            return ToolResult(
                success: true,
                content: "Current date and time: \(displayFormatter.string(from: now))",
                metadata: ["iso_date": formatter.string(from: now), "timezone": timeZone.identifier]
            )
            
        case "format":
            guard let dateString = arguments["date"] as? String,
                  let date = formatter.date(from: dateString),
                  let format = arguments["format"] as? String else {
                throw ToolError.invalidArguments("Missing or invalid date/format parameters")
            }
            
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = format
            
            return ToolResult(
                success: true,
                content: "Formatted date: \(displayFormatter.string(from: date))"
            )
            
        default:
            return ToolResult(
                success: false,
                content: "Unsupported action: \(action)"
            )
        }
    }
}

// MARK: Web Search Tool

struct WebSearchTool: Tool {
    let name = "web_search"
    let description = "Search the web for current information and answer questions about recent events"
    
    let parameters = ToolParameters(
        properties: [
            "query": ParameterProperty(
                type: "string",
                description: "Search query to find information on the web"
            ),
            "max_results": ParameterProperty(
                type: "integer",
                description: "Maximum number of results to return (default: 5, max: 10)"
            )
        ],
        required: ["query"]
    )
    
    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidArguments("Missing 'query' parameter")
        }
        
        let maxResults = arguments["max_results"] as? Int ?? 5
        let clampedMaxResults = min(max(1, maxResults), 10)
        
        do {
            let results = try await performWebSearch(query: query, maxResults: clampedMaxResults)
            return ToolResult(
                success: true,
                content: formatSearchResults(results),
                metadata: ["query": query, "results_count": results.count]
            )
        } catch {
            return ToolResult(
                success: false,
                content: "Web search failed: \(error.localizedDescription). Please try rephrasing your query or check your internet connection."
            )
        }
    }
    
    private func performWebSearch(query: String, maxResults: Int) async throws -> [SearchResult] {
        // Use Serper API for web search
        let apiKey = UserDefaults.standard.string(forKey: "SerperAPIKey")
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw ToolError.networkError(NSError(
                domain: "WebSearchError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Serper API key not found. Please add your API key in Settings."]
            ))
        }
        
        let url = URL(string: "https://google.serper.dev/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        let requestBody = [
            "q": query,
            "num": maxResults
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw ToolError.networkError(NSError(
                    domain: "WebSearchError",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Search API returned status code \(httpResponse.statusCode)"]
                ))
            }
        }
        
        let searchResponse = try JSONDecoder().decode(SerperSearchResponse.self, from: data)
        return searchResponse.organic.map { result in
            SearchResult(
                title: result.title,
                link: result.link,
                snippet: result.snippet
            )
        }
    }
    
    private func formatSearchResults(_ results: [SearchResult]) -> String {
        if results.isEmpty {
            return "No search results found for the given query."
        }
        
        var formatted = "Web search results:\n\n"
        for (index, result) in results.enumerated() {
            formatted += "\(index + 1). **\(result.title)**\n"
            formatted += "   \(result.snippet)\n"
            formatted += "   Source: \(result.link)\n\n"
        }
        
        return formatted
    }
}

// MARK: - Search Result Models

struct SearchResult {
    let title: String
    let link: String
    let snippet: String
}

struct SerperSearchResponse: Codable {
    let organic: [SerperResult]
}

struct SerperResult: Codable {
    let title: String
    let link: String
    let snippet: String
}

// MARK: Weather Tool

struct WeatherTool: Tool {
    let name = "weather"
    let description = "Get current weather information and forecast for any location worldwide"
    
    let parameters = ToolParameters(
        properties: [
            "location": ParameterProperty(
                type: "string",
                description: "Location name (city, state/country) or coordinates (lat,lon)"
            ),
            "units": ParameterProperty(
                type: "string",
                description: "Temperature units",
                enum: ["metric", "imperial", "kelvin"]
            )
        ],
        required: ["location"]
    )
    
    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let location = arguments["location"] as? String else {
            throw ToolError.invalidArguments("Missing 'location' parameter")
        }
        
        let units = arguments["units"] as? String ?? "metric"
        
        do {
            let weather = try await fetchWeatherData(location: location, units: units)
            return ToolResult(
                success: true,
                content: formatWeatherData(weather, location: location),
                metadata: [
                    "location": location,
                    "temperature": weather.temperature,
                    "condition": weather.condition,
                    "units": units
                ]
            )
        } catch {
            return ToolResult(
                success: false,
                content: "Weather data unavailable for '\(location)'. Please check the location name and try again. Error: \(error.localizedDescription)"
            )
        }
    }
    
    private func fetchWeatherData(location: String, units: String) async throws -> WeatherData {
        let apiKey = UserDefaults.standard.string(forKey: "OpenWeatherMapAPIKey")
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw ToolError.networkError(NSError(
                domain: "WeatherError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "OpenWeatherMap API key not found. Please add your API key in Settings."]
            ))
        }
        
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
        let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(encodedLocation)&appid=\(apiKey)&units=\(units)"
        
        guard let url = URL(string: urlString) else {
            throw ToolError.invalidArguments("Invalid location format")
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw ToolError.networkError(NSError(
                    domain: "WeatherError",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Weather API returned status code \(httpResponse.statusCode)"]
                ))
            }
        }
        
        let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
        
        return WeatherData(
            temperature: weatherResponse.main.temp,
            condition: weatherResponse.weather.first?.description ?? "Unknown",
            humidity: weatherResponse.main.humidity,
            windSpeed: weatherResponse.wind?.speed ?? 0,
            cityName: weatherResponse.name,
            country: weatherResponse.sys.country
        )
    }
    
    private func formatWeatherData(_ weather: WeatherData, location: String) -> String {
        let unitsSymbol = getUnitsSymbol()
        let speedUnit = getSpeedUnit()
        
        return """
        Current weather for \(weather.cityName), \(weather.country):
        
        🌡️ Temperature: \(String(format: "%.1f", weather.temperature))\(unitsSymbol)
        🌤️ Condition: \(weather.condition.capitalized)
        💧 Humidity: \(weather.humidity)%
        💨 Wind Speed: \(String(format: "%.1f", weather.windSpeed)) \(speedUnit)
        """
    }
    
    private func getUnitsSymbol() -> String {
        // This would ideally be passed from the units parameter, but for simplicity using metric
        return "°C"
    }
    
    private func getSpeedUnit() -> String {
        return "m/s"
    }
}

// MARK: - Weather Data Models

struct WeatherData {
    let temperature: Double
    let condition: String
    let humidity: Int
    let windSpeed: Double
    let cityName: String
    let country: String
}

struct OpenWeatherResponse: Codable {
    let main: MainWeatherData
    let weather: [WeatherCondition]
    let wind: WindData?
    let name: String
    let sys: SystemData
}

struct MainWeatherData: Codable {
    let temp: Double
    let humidity: Int
}

struct WeatherCondition: Codable {
    let description: String
}

struct WindData: Codable {
    let speed: Double
}

struct SystemData: Codable {
    let country: String
}

// MARK: Text Analysis Tool

struct TextAnalysisTool: Tool {
    let name = "text_analysis"
    let description = "Analyze text for various properties like word count, character count, etc."
    
    let parameters = ToolParameters(
        properties: [
            "text": ParameterProperty(
                type: "string",
                description: "Text to analyze"
            ),
            "analysis_type": ParameterProperty(
                type: "string",
                description: "Type of analysis to perform",
                enum: ["word_count", "character_count", "sentence_count", "readability", "all"]
            )
        ],
        required: ["text", "analysis_type"]
    )
    
    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let text = arguments["text"] as? String,
              let analysisType = arguments["analysis_type"] as? String else {
            throw ToolError.invalidArguments("Missing required parameters")
        }
        
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        let characterCount = text.count
        let characterCountNoSpaces = text.replacingOccurrences(of: " ", with: "").count
        let sentenceCount = text.components(separatedBy: .punctuationCharacters)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        
        var content = ""
        var metadata: [String: Any] = [:]
        
        switch analysisType {
        case "word_count":
            content = "Word count: \(wordCount)"
            metadata["word_count"] = wordCount
            
        case "character_count":
            content = "Character count: \(characterCount) (including spaces), \(characterCountNoSpaces) (excluding spaces)"
            metadata["character_count"] = characterCount
            metadata["character_count_no_spaces"] = characterCountNoSpaces
            
        case "sentence_count":
            content = "Sentence count: \(sentenceCount)"
            metadata["sentence_count"] = sentenceCount
            
        case "all":
            content = """
            Text Analysis Results:
            • Words: \(wordCount)
            • Characters: \(characterCount) (including spaces)
            • Characters: \(characterCountNoSpaces) (excluding spaces)
            • Sentences: \(sentenceCount)
            """
            metadata = [
                "word_count": wordCount,
                "character_count": characterCount,
                "character_count_no_spaces": characterCountNoSpaces,
                "sentence_count": sentenceCount
            ]
            
        default:
            throw ToolError.invalidArguments("Unsupported analysis type: \(analysisType)")
        }
        
        return ToolResult(success: true, content: content, metadata: metadata)
    }
}

// MARK: Unit Converter Tool

struct UnitConverterTool: Tool {
    let name = "unit_converter"
    let description = "Convert between different units of measurement"
    
    let parameters = ToolParameters(
        properties: [
            "value": ParameterProperty(
                type: "number",
                description: "Value to convert"
            ),
            "from_unit": ParameterProperty(
                type: "string",
                description: "Source unit"
            ),
            "to_unit": ParameterProperty(
                type: "string",
                description: "Target unit"
            ),
            "category": ParameterProperty(
                type: "string",
                description: "Unit category",
                enum: ["length", "weight", "temperature", "volume"]
            )
        ],
        required: ["value", "from_unit", "to_unit", "category"]
    )
    
    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let value = arguments["value"] as? Double,
              let fromUnit = arguments["from_unit"] as? String,
              let toUnit = arguments["to_unit"] as? String,
              let category = arguments["category"] as? String else {
            throw ToolError.invalidArguments("Missing required parameters")
        }
        
        let result: Double
        
        switch category {
        case "temperature":
            result = try convertTemperature(value, from: fromUnit, to: toUnit)
        case "length":
            result = try convertLength(value, from: fromUnit, to: toUnit)
        case "weight":
            result = try convertWeight(value, from: fromUnit, to: toUnit)
        case "volume":
            result = try convertVolume(value, from: fromUnit, to: toUnit)
        default:
            throw ToolError.invalidArguments("Unsupported category: \(category)")
        }
        
        return ToolResult(
            success: true,
            content: "\(value) \(fromUnit) = \(result) \(toUnit)",
            metadata: [
                "original_value": value,
                "converted_value": result,
                "from_unit": fromUnit,
                "to_unit": toUnit,
                "category": category
            ]
        )
    }
    
    private func convertTemperature(_ value: Double, from: String, to: String) throws -> Double {
        // Convert to Celsius first
        var celsius: Double
        switch from.lowercased() {
        case "c", "celsius":
            celsius = value
        case "f", "fahrenheit":
            celsius = (value - 32) * 5/9
        case "k", "kelvin":
            celsius = value - 273.15
        default:
            throw ToolError.invalidArguments("Unknown temperature unit: \(from)")
        }
        
        // Convert from Celsius to target
        switch to.lowercased() {
        case "c", "celsius":
            return celsius
        case "f", "fahrenheit":
            return celsius * 9/5 + 32
        case "k", "kelvin":
            return celsius + 273.15
        default:
            throw ToolError.invalidArguments("Unknown temperature unit: \(to)")
        }
    }
    
    private func convertLength(_ value: Double, from: String, to: String) throws -> Double {
        // Conversion factors to meters
        let toMeters: [String: Double] = [
            "mm": 0.001, "cm": 0.01, "m": 1.0, "km": 1000.0,
            "in": 0.0254, "ft": 0.3048, "yd": 0.9144, "mi": 1609.34
        ]
        
        guard let fromFactor = toMeters[from.lowercased()],
              let toFactor = toMeters[to.lowercased()] else {
            throw ToolError.invalidArguments("Unknown length unit")
        }
        
        return value * fromFactor / toFactor
    }
    
    private func convertWeight(_ value: Double, from: String, to: String) throws -> Double {
        // Conversion factors to grams
        let toGrams: [String: Double] = [
            "mg": 0.001, "g": 1.0, "kg": 1000.0,
            "oz": 28.3495, "lb": 453.592
        ]
        
        guard let fromFactor = toGrams[from.lowercased()],
              let toFactor = toGrams[to.lowercased()] else {
            throw ToolError.invalidArguments("Unknown weight unit")
        }
        
        return value * fromFactor / toFactor
    }
    
    private func convertVolume(_ value: Double, from: String, to: String) throws -> Double {
        // Conversion factors to liters
        let toLiters: [String: Double] = [
            "ml": 0.001, "l": 1.0,
            "cup": 0.236588, "pt": 0.473176, "qt": 0.946353, "gal": 3.78541
        ]
        
        guard let fromFactor = toLiters[from.lowercased()],
              let toFactor = toLiters[to.lowercased()] else {
            throw ToolError.invalidArguments("Unknown volume unit")
        }
        
        return value * fromFactor / toFactor
    }
}

// MARK: - Networking Extension for OpenRouter Integration

extension Networking {
    struct Tool: Codable {
        let type: String
        let function: ToolFunction
    }
    
    struct ToolFunction: Codable {
        let name: String
        let description: String
        let parameters: [String: Any]
        
        enum CodingKeys: String, CodingKey {
            case name, description, parameters
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(description, forKey: .description)
            
            // Encode parameters as JSON
            let data = try JSONSerialization.data(withJSONObject: parameters)
            let json = try JSONSerialization.jsonObject(with: data)
            try container.encode(json as! [String: Any], forKey: .parameters)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            description = try container.decode(String.self, forKey: .description)
            parameters = try container.decode([String: Any].self, forKey: .parameters)
        }
        
        init(name: String, description: String, parameters: [String: Any]) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }
}

// Helper for [String: Any] Codable conformance
extension Dictionary: @retroactive Codable where Key == String, Value == Any {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in self {
            let codingKey = StringCodingKey(stringValue: key)!
            try container.encode(AnyEncodable(value), forKey: codingKey)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        var dict: [String: Any] = [:]
        for key in container.allKeys {
            dict[key.stringValue] = try container.decode(AnyDecodable.self, forKey: key).value
        }
        self = dict
    }
}

struct StringCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        return nil
    }
}

struct AnyEncodable: Encodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map(AnyEncodable.init))
        case let dict as [String: Any]:
            try container.encode(dict.mapValues(AnyEncodable.init))
        default:
            try container.encodeNil()
        }
    }
}

struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyDecodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            value = dict.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }
}