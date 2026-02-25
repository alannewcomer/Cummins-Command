import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:myapp/config/constants.dart';
import 'package:myapp/models/vehicle.dart';

/// Firebase AI Logic SDK wrapper providing both fast (Flash) and deep (Pro)
/// Gemini model access for the Cummins Command app.
///
/// Uses FirebaseAI.googleAI() to access Gemini models:
/// - Flash (gemini-2.5-flash): status strip messages, gauge annotations
/// - Pro (gemini-3.1-pro-preview): deep analysis, dashboard generation, chat
///
/// Designed for use with Riverpod providers. Pass the active [Vehicle] so the
/// system instruction reflects the actual truck, not hardcoded defaults.
class AiService {
  late final GenerativeModel _flashModel;
  late final GenerativeModel _proModel;
  late final GenerativeModel _explorerFlashModel;

  static String _buildSystemInstruction(Vehicle? vehicle) {
    final String vehicleDesc;
    if (vehicle != null) {
      final name =
          '${vehicle.year} ${vehicle.make} ${vehicle.model}${vehicle.trim.isNotEmpty ? ' ${vehicle.trim}' : ''}';
      final engine =
          vehicle.engine.isNotEmpty ? vehicle.engine : 'diesel engine';
      final trans = vehicle.transmissionType.isNotEmpty
          ? vehicle.transmissionType
          : 'automatic transmission';
      vehicleDesc = '$name with a $engine ($trans)';
    } else {
      vehicleDesc = 'a diesel truck';
    }

    return '''
You are the AI engine for Cummins Command, a diesel truck monitoring app
for $vehicleDesc.

You are an expert in:
- Diesel engine diagnostics and performance optimization
- OBD2 and J1939 CAN bus protocols
- Heavy-duty towing dynamics and thermal management
- Preventive maintenance scheduling

Keep responses concise and actionable. Use technical language when
appropriate but remain accessible. Always reference specific parameter
values when available.
''';
  }

  AiService({Vehicle? vehicle}) {
    final systemInstruction = _buildSystemInstruction(vehicle);
    final ai = FirebaseAI.googleAI();

    _flashModel = ai.generativeModel(
      model: AppConstants.geminiFlashModel,
      systemInstruction: Content.system(systemInstruction),
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: 256,
        topP: 0.9,
      ),
    );

    _proModel = ai.generativeModel(
      model: AppConstants.geminiProModel,
      systemInstruction: Content.system(systemInstruction),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 4096,
        topP: 0.95,
      ),
    );

    _explorerFlashModel = ai.generativeModel(
      model: AppConstants.geminiExplorerFlashModel,
      systemInstruction: Content.system('''
$systemInstruction

You are analyzing time-series sensor data from the vehicle's Data Explorer.
The user has selected specific parameters and a time range. You will receive
aggregated statistics (min, max, avg, median, count) and ~50 downsampled
data points per parameter so you can identify trends.

Be concise but specific — reference actual values. Use plain text, no markdown
headers. Keep responses under 200 words unless the user asks for detail.
'''),
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: 1024,
        topP: 0.9,
      ),
    );
  }

  // ─── Flash Model Methods (Fast, Short Responses) ───

  /// Generate a concise status strip message from live data.
  ///
  /// Uses Flash for speed. Returns a single-line status message
  /// suitable for display at the top of the command center.
  /// Example: "Cruising steady, all temps nominal. EGT trending up slightly."
  Future<String> getStatusStripMessage(
    Map<String, double> liveData, {
    Map<String, double>? baseline,
  }) async {
    final dataStr = _formatLiveData(liveData);
    final baselineStr = baseline != null
        ? '\n30-day baseline averages:\n${_formatLiveData(baseline)}'
        : '';

    final prompt = '''
Current live vehicle data:
$dataStr
$baselineStr

Write a single concise sentence (max 80 chars) describing the current
vehicle status. Focus on anything notable or concerning. If everything
is normal, note the driving mode (idle, city, highway, towing).
Do NOT use any special formatting or markdown.
''';

    try {
      final response = await _flashModel.generateContent([
        Content.text(prompt),
      ]);
      return response.text?.trim() ?? 'Monitoring active';
    } catch (e) {
      return 'Status unavailable';
    }
  }

  /// Generate a brief annotation for a gauge showing a specific parameter.
  ///
  /// Uses Flash for speed. Returns a short contextual note.
  /// Example for EGT at 850F: "Normal range for highway cruise."
  Future<String> getGaugeAnnotation(
    String pidId,
    double value, {
    double? avg30Day,
  }) async {
    final avgStr = avg30Day != null
        ? ' Your 30-day average is ${avg30Day.toStringAsFixed(1)}.'
        : '';

    final prompt = '''
Parameter: $pidId
Current value: ${value.toStringAsFixed(1)}
$avgStr

Write a brief annotation (max 40 chars) for this gauge value in a
diesel truck monitoring app. Note if it's normal, concerning, or notable.
No markdown, no special formatting, just plain text.
''';

    try {
      final response = await _flashModel.generateContent([
        Content.text(prompt),
      ]);
      return response.text?.trim() ?? '';
    } catch (e) {
      return '';
    }
  }

  // ─── Pro Model Methods (Deep Analysis) ───

  /// Perform deep analysis on vehicle data with a custom query.
  ///
  /// Uses Pro model for thorough, multi-step reasoning.
  /// [context] can include drive history, maintenance records, etc.
  Future<String> analyzeData(
    String query,
    Map<String, dynamic> context,
  ) async {
    final contextJson = const JsonEncoder.withIndent('  ').convert(context);

    final prompt = '''
User query: $query

Vehicle data context:
$contextJson

Provide a thorough analysis. Include:
1. Direct answer to the query
2. Supporting data points
3. Any concerns or recommendations
4. Confidence level in your assessment

Use clear section headers. Keep it under 500 words.
''';

    try {
      final response = await _proModel.generateContent([
        Content.text(prompt),
      ]);
      return response.text?.trim() ?? 'Analysis could not be completed.';
    } catch (e) {
      throw AiServiceException('Analysis failed: $e');
    }
  }

  /// Run a comprehensive analysis on drive data for a given scope.
  ///
  /// Uses Pro model with diesel-specific scoring thresholds.
  /// Returns parsed JSON with healthScore, summary, anomalies, recommendations, highlights.
  Future<Map<String, dynamic>> runAnalysis(
    String scope,
    Map<String, dynamic> driveData,
  ) async {
    final contextJson = const JsonEncoder.withIndent('  ').convert(driveData);

    final prompt = '''
Analyze the following diesel truck drive data for the scope: $scope.

Drive data:
$contextJson

Score the vehicle health 0-100 using these diesel-specific thresholds:
- EGT: Normal < 800F, Caution 800-1100F, Critical > 1100F
- Coolant Temp: Normal 180-210F, Caution 210-230F, Critical > 230F
- Trans Temp: Normal < 200F, Caution 200-240F, Critical > 240F
- Oil Temp: Normal 200-230F, Caution 230-260F, Critical > 260F
- Boost: Normal 20-35 PSI under load, low if < 15 PSI under load
- MPG: Normal 15-22 highway, below 12 may indicate issues

Respond with ONLY valid JSON (no markdown code fences) in this exact format:
{
  "summary": "2-4 sentence overview of vehicle condition and driving patterns",
  "healthScore": 85,
  "anomalies": ["description of any concerning readings or patterns"],
  "recommendations": ["actionable maintenance or driving recommendations"],
  "highlights": {
    "peakEGT": "value and context",
    "avgMPG": "value and context",
    "totalMiles": "value",
    "dpfRegens": "count and context"
  }
}

If all readings are within normal ranges, anomalies should be an empty array.
Be specific — reference actual values from the data. Keep each item concise.
''';

    try {
      final response = await _proModel.generateContent([
        Content.text(prompt),
      ]);
      final text = response.text?.trim() ?? '';
      final jsonStr = _extractJson(text);

      final decoded = json.decode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Response is not a JSON object');
      }

      // Validate required fields and types
      if (!decoded.containsKey('healthScore') || !decoded.containsKey('summary')) {
        throw const FormatException('Missing required analysis fields');
      }
      if (decoded['healthScore'] is! num) {
        throw const FormatException('healthScore must be a number');
      }
      if (decoded['summary'] is! String) {
        throw const FormatException('summary must be a string');
      }

      // Clamp healthScore to valid range
      final score = (decoded['healthScore'] as num).toInt().clamp(0, 100);
      decoded['healthScore'] = score;

      // Validate optional list fields are actually lists
      for (final key in ['anomalies', 'recommendations']) {
        if (decoded.containsKey(key) && decoded[key] is! List) {
          decoded[key] = <String>[];
        }
      }

      // Validate highlights is a map if present
      if (decoded.containsKey('highlights') &&
          decoded['highlights'] is! Map) {
        decoded['highlights'] = <String, dynamic>{};
      }

      return decoded;
    } catch (e) {
      throw AiServiceException('Analysis failed: $e');
    }
  }

  /// Generate a dashboard layout JSON from a natural language prompt.
  ///
  /// Uses Pro model to understand the user's intent and produce a
  /// valid dashboard configuration.
  Future<Map<String, dynamic>> generateDashboardJson(String prompt) async {
    final fullPrompt = '''
Generate a dashboard layout for a diesel truck monitoring app.

User request: $prompt

Available parameter IDs:
rpm, speed, coolantTemp, intakeTemp, maf, throttlePos, boostPressure,
egt, transTemp, oilTemp, oilPressure, engineLoad, turboSpeed,
dpfSootLoad, dpfRegenStatus, defLevel, defTemp, railPressure,
fuelRate, fuelLevel, batteryVoltage, ambientTemp, barometric,
odometer, engineHours

Available widget types:
radialGauge, linearBar, digital, sparkline, progressRing, statusIndicator

Respond with ONLY valid JSON (no markdown code fences) in this format:
{
  "name": "Dashboard Name",
  "description": "Brief description",
  "icon": "material_icon_name",
  "source": "ai_generated",
  "layout": {
    "columns": 3,
    "rows": 4,
    "widgets": [
      {"type": "radialGauge", "param": "paramId", "col": 0, "row": 0, "colSpan": 1, "rowSpan": 1}
    ]
  }
}

Choose widgets and parameters that best match the user's intent.
Use 3 columns, up to 4 rows. Prioritize the most relevant parameters.
''';

    try {
      final response = await _proModel.generateContent([
        Content.text(fullPrompt),
      ]);
      final text = response.text?.trim() ?? '';

      // Parse JSON from response, handling potential markdown fences
      final jsonStr = _extractJson(text);

      final decoded = json.decode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Response is not a JSON object');
      }

      // Validate required fields and types
      if (!decoded.containsKey('layout') || !decoded.containsKey('name')) {
        throw const FormatException('Missing required dashboard fields');
      }
      if (decoded['name'] is! String) {
        throw const FormatException('name must be a string');
      }
      if (decoded['layout'] is! Map) {
        throw const FormatException('layout must be an object');
      }

      return decoded;
    } catch (e) {
      throw AiServiceException('Dashboard generation failed: $e');
    }
  }

  /// Chat with the AI about the vehicle.
  ///
  /// Uses Pro model with conversation history for context-aware responses.
  /// [history] is a list of previous messages with 'role' and 'content' keys.
  Future<String> chat(
    String message,
    List<Map<String, String>> history,
  ) async {
    try {
      // Build conversation history as Content objects
      final contents = <Content>[];

      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (role == 'user') {
          contents.add(Content.text(content));
        } else {
          contents.add(Content('model', [TextPart(content)]));
        }
      }

      // Add current message
      contents.add(Content.text(message));

      // Limit history to avoid token overflow
      if (contents.length > AppConstants.maxChatHistory) {
        contents.removeRange(0, contents.length - AppConstants.maxChatHistory);
      }

      final response = await _proModel.generateContent(contents);
      return response.text?.trim() ?? 'I could not generate a response.';
    } catch (e) {
      throw AiServiceException('Chat failed: $e');
    }
  }

  // ─── Explorer Chat (Fast, Data-Aware) ───

  /// Chat about Data Explorer data using the Flash Preview model.
  ///
  /// [message] is the user's current question.
  /// [history] is prior conversation turns.
  /// [dataContext] is the aggregated stats + downsampled series from
  /// [buildExplorerDataContext].
  Future<String> explorerChat(
    String message,
    List<Map<String, String>> history,
    Map<String, dynamic> dataContext,
  ) async {
    try {
      final contextJson = const JsonEncoder.withIndent('  ').convert(dataContext);
      final contents = <Content>[];

      // First turn: inject the data context so Gemini sees it
      contents.add(Content.text(
        'Here is the vehicle sensor data I\'m looking at:\n$contextJson',
      ));
      contents.add(Content('model', [
        TextPart('I can see your data. What would you like to know?'),
      ]));

      // Replay conversation history
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (role == 'user') {
          contents.add(Content.text(content));
        } else {
          contents.add(Content('model', [TextPart(content)]));
        }
      }

      // Add current message
      contents.add(Content.text(message));

      // Limit history to avoid token overflow
      if (contents.length > AppConstants.maxChatHistory) {
        // Always keep the first 2 (data context pair)
        final tail = contents.sublist(2);
        if (tail.length > AppConstants.maxChatHistory - 2) {
          tail.removeRange(0, tail.length - (AppConstants.maxChatHistory - 2));
        }
        contents
          ..removeRange(2, contents.length)
          ..addAll(tail);
      }

      final response = await _explorerFlashModel.generateContent(contents);
      return response.text?.trim() ?? 'I could not generate a response.';
    } catch (e) {
      throw AiServiceException('Explorer chat failed: $e');
    }
  }

  // ─── Helpers ───

  /// Format live data map into a human-readable string for AI prompts.
  String _formatLiveData(Map<String, double> data) {
    final buffer = StringBuffer();
    for (final entry in data.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value.toStringAsFixed(1)}');
    }
    return buffer.toString();
  }

  /// Extract JSON from a response that may be wrapped in markdown code fences.
  String _extractJson(String text) {
    // Try to find JSON between code fences
    final fenceMatch = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)```').firstMatch(text);
    if (fenceMatch != null) {
      return fenceMatch.group(1)!.trim();
    }

    // Try to find a JSON object in the text
    final braceStart = text.indexOf('{');
    final braceEnd = text.lastIndexOf('}');
    if (braceStart >= 0 && braceEnd > braceStart) {
      return text.substring(braceStart, braceEnd + 1);
    }

    return text;
  }
}

/// Exception thrown by AiService when an AI operation fails.
class AiServiceException implements Exception {
  final String message;
  const AiServiceException(this.message);

  @override
  String toString() => 'AiServiceException: $message';
}
