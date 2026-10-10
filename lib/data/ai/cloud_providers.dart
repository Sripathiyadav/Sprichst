/// How a provider's API is spoken.
enum CloudApi {
  /// `POST /chat/completions` with a bearer key: OpenAI and the many services
  /// that copy its API (Groq, Gemini, xAI, Mistral, DeepSeek, OpenRouter…).
  openAi,

  /// Anthropic's Messages API (`POST /messages`, `x-api-key`).
  anthropic,
}

/// A model suggested for a provider. The learner can also type any other
/// model id the provider offers.
class CloudModel {
  const CloudModel(this.id, this.label, this.note);
  final String id;
  final String label;
  final String note;
}

/// One AI platform the learner can bring their own key for.
class CloudProvider {
  const CloudProvider({
    required this.id,
    required this.name,
    required this.api,
    required this.baseUrl,
    required this.keyConsole,
    required this.keyHint,
    required this.models,
    this.transcriptionModel,
    this.jsonMode = true,
    this.maxTokensField = 'max_tokens',
    this.freeTier = false,
    this.keyOptional = false,
  });

  /// Stable id, used in storage names: never rename one.
  final String id;
  final String name;
  final CloudApi api;

  /// Empty for [custom]: the learner types it.
  final String baseUrl;

  /// Where the learner creates a key, shown in the setup steps.
  final String keyConsole;

  /// What a key usually starts with, as a hint in the key field.
  final String keyHint;
  final List<CloudModel> models;

  /// Whisper-style `/audio/transcriptions` model, when the provider has one.
  /// Without it, speech is recognised on the phone.
  final String? transcriptionModel;

  /// Whether the provider accepts `response_format: {type: json_object}`.
  final bool jsonMode;

  /// OpenAI's newer models want `max_completion_tokens`.
  final String maxTokensField;
  final bool freeTier;

  /// A self-hosted server may not need a key at all.
  final bool keyOptional;

  bool get isCustom => id == custom.id;
  bool get canTranscribe => transcriptionModel != null;
  String get defaultModel => models.isEmpty ? '' : models.first.id;

  static CloudProvider byId(String? id) =>
      cloudProviders.firstWhere((p) => p.id == id, orElse: () => groq);

  static const groq = CloudProvider(
    id: 'groq',
    name: 'Groq',
    api: CloudApi.openAi,
    baseUrl: 'https://api.groq.com/openai/v1',
    keyConsole: 'console.groq.com/keys',
    keyHint: 'gsk_…',
    transcriptionModel: 'whisper-large-v3-turbo',
    freeTier: true,
    models: [
      CloudModel('llama-3.3-70b-versatile', 'Llama 3.3 70B (best answers)',
          'The most accurate German. Uses your daily allowance faster.'),
      CloudModel('llama-3.1-8b-instant', 'Llama 3.1 8B (more messages)',
          'Quicker and lighter, so your daily allowance lasts longer.'),
    ],
  );

  static const gemini = CloudProvider(
    id: 'gemini',
    name: 'Google Gemini',
    api: CloudApi.openAi,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    keyConsole: 'aistudio.google.com/apikey',
    keyHint: 'AIza…',
    freeTier: true,
    jsonMode: false,
    models: [
      CloudModel('gemini-2.5-flash', 'Gemini 2.5 Flash',
          'Fast, very good German, generous free tier.'),
      CloudModel('gemini-2.5-flash-lite', 'Gemini 2.5 Flash-Lite',
          'Lighter and cheaper, so the free tier lasts longer.'),
    ],
  );

  static const openAi = CloudProvider(
    id: 'openai',
    name: 'OpenAI',
    api: CloudApi.openAi,
    baseUrl: 'https://api.openai.com/v1',
    keyConsole: 'platform.openai.com/api-keys',
    keyHint: 'sk-…',
    transcriptionModel: 'whisper-1',
    maxTokensField: 'max_completion_tokens',
    models: [
      CloudModel('gpt-4.1-mini', 'GPT-4.1 mini',
          'Quick and inexpensive, good German.'),
      CloudModel('gpt-4.1', 'GPT-4.1', 'Stronger answers, costs more.'),
    ],
  );

  static const anthropic = CloudProvider(
    id: 'anthropic',
    name: 'Anthropic Claude',
    api: CloudApi.anthropic,
    baseUrl: 'https://api.anthropic.com/v1',
    keyConsole: 'console.anthropic.com/settings/keys',
    keyHint: 'sk-ant-…',
    models: [
      CloudModel('claude-haiku-5-5', 'Claude Haiku 5.5',
          'Fast and inexpensive, natural German.'),
      CloudModel('claude-sonnet-5-5', 'Claude Sonnet 5.5',
          'Stronger explanations, costs more.'),
    ],
  );

  static const xai = CloudProvider(
    id: 'xai',
    name: 'xAI Grok',
    api: CloudApi.openAi,
    baseUrl: 'https://api.x.ai/v1',
    keyConsole: 'console.x.ai',
    keyHint: 'xai-…',
    models: [
      CloudModel('grok-3-mini', 'Grok 3 mini', 'Quick and inexpensive.'),
      CloudModel('grok-3', 'Grok 3', 'Stronger answers, costs more.'),
    ],
  );

  static const mistral = CloudProvider(
    id: 'mistral',
    name: 'Mistral',
    api: CloudApi.openAi,
    baseUrl: 'https://api.mistral.ai/v1',
    keyConsole: 'console.mistral.ai/api-keys',
    keyHint: 'Your Mistral key',
    freeTier: true,
    models: [
      CloudModel('mistral-small-latest', 'Mistral Small',
          'European model, strong in German, free tier available.'),
      CloudModel('mistral-large-latest', 'Mistral Large',
          'Stronger answers, costs more.'),
    ],
  );

  static const deepSeek = CloudProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    api: CloudApi.openAi,
    baseUrl: 'https://api.deepseek.com/v1',
    keyConsole: 'platform.deepseek.com/api_keys',
    keyHint: 'sk-…',
    models: [
      CloudModel('deepseek-chat', 'DeepSeek Chat', 'Very inexpensive.'),
    ],
  );

  static const openRouter = CloudProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    api: CloudApi.openAi,
    baseUrl: 'https://openrouter.ai/api/v1',
    keyConsole: 'openrouter.ai/keys',
    keyHint: 'sk-or-…',
    jsonMode: false,
    freeTier: true,
    models: [
      CloudModel('openrouter/auto', 'Automatic',
          'OpenRouter picks a model for each message.'),
      CloudModel('meta-llama/llama-3.3-70b-instruct:free',
          'Llama 3.3 70B (free)', 'Free, with a daily limit.'),
    ],
  );

  /// Any other OpenAI-compatible server (Together, Fireworks, Perplexity, a
  /// self-hosted LiteLLM or vLLM…): the learner types its address and model.
  static const custom = CloudProvider(
    id: 'custom',
    name: 'Other (OpenAI-compatible)',
    api: CloudApi.openAi,
    baseUrl: '',
    keyConsole: 'your provider\'s dashboard',
    keyHint: 'Your API key',
    jsonMode: false,
    keyOptional: true,
    models: [],
  );
}

/// Every provider, in the order the settings list them.
const cloudProviders = <CloudProvider>[
  CloudProvider.groq,
  CloudProvider.gemini,
  CloudProvider.openAi,
  CloudProvider.anthropic,
  CloudProvider.xai,
  CloudProvider.mistral,
  CloudProvider.deepSeek,
  CloudProvider.openRouter,
  CloudProvider.custom,
];
