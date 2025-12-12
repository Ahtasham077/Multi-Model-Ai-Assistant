# Usage Examples

This document provides detailed examples of how to use the Multi-Model AI Assistant.

## Basic Setup

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure API keys:**
   Create a `.env` file from the example:
   ```bash
   cp .env.example .env
   ```

3. **Edit `.env` file with your API keys:**
   ```
   OPENAI_API_KEY=sk-your-actual-key-here
   ANTHROPIC_API_KEY=sk-ant-your-actual-key-here
   # ... add other keys as needed
   ```

## Running the Assistant

### Basic Usage

Start the interactive assistant:
```bash
python main.py
```

### Example Interactive Session

```
============================================================
🤖 Multi-Model AI Assistant 🤖
============================================================

Available AI Models:
============================================================
1. OPENAI: OpenAI gpt-3.5-turbo
2. ANTHROPIC: Anthropic claude-3-haiku-20240307
3. GEMINI: Google gemini-pro

============================================================

Select a model (1-3) or 'q' to quit: 1

✓ Selected: OpenAI gpt-3.5-turbo

Enter your message (or 'back' to select another model, 'q' to quit):
You: Explain quantum computing in simple terms

🤖 OpenAI gpt-3.5-turbo is thinking...

OpenAI gpt-3.5-turbo: 
Quantum computing is a type of computing that uses quantum mechanics...
[response continues]

============================================================

Select a model (1-3) or 'q' to quit: 2

✓ Selected: Anthropic claude-3-haiku-20240307

Enter your message (or 'back' to select another model, 'q' to quit):
You: Explain quantum computing in simple terms

🤖 Anthropic claude-3-haiku-20240307 is thinking...

Anthropic claude-3-haiku-20240307:
Quantum computing harnesses the unique properties of quantum mechanics...
[response continues]
```

## Use Cases

### 1. Model Comparison

Compare how different AI models respond to the same prompt:

1. Start the assistant
2. Select Model 1 (e.g., OpenAI)
3. Ask your question
4. Note the response
5. Type 'back' to return to model selection
6. Select Model 2 (e.g., Claude)
7. Ask the same question
8. Compare the responses

### 2. Task-Specific Model Selection

Different models excel at different tasks:

- **OpenAI GPT-3.5/GPT-4**: General-purpose, coding, creative writing
- **Anthropic Claude**: Long-form content, analysis, safety-conscious responses
- **Google Gemini**: Multimodal tasks, Google ecosystem integration
- **Cohere**: Specialized business applications, embeddings
- **Hugging Face**: Open-source models, research, experimentation

### 3. Cost Optimization

Use different models based on task complexity:

- Simple queries → Use faster, cheaper models (GPT-3.5, Claude Haiku)
- Complex tasks → Use advanced models (GPT-4, Claude Opus)
- Experimentation → Use open-source models (Hugging Face)

### 4. Fallback Strategy

If one API is down or slow:

1. Try primary model
2. If it fails, switch to alternative model
3. Continue your work without interruption

## Tips

### Keyboard Shortcuts

- **q**: Quit the application
- **back**: Return to model selection
- **Ctrl+C**: Emergency exit

### Best Practices

1. **Start with one API key**: Don't need all five to get started
2. **Test with simple prompts first**: Ensure your API keys work
3. **Monitor API usage**: Each service has different pricing
4. **Keep API keys secure**: Never commit `.env` file to git
5. **Use appropriate models**: Match the model to your task

### Common Issues

**Problem**: "No AI models are configured"
- **Solution**: Check your `.env` file has valid API keys

**Problem**: "Error generating response"
- **Solution**: Verify your API key is valid and has credits/quota

**Problem**: Model responds slowly
- **Solution**: Some models are slower than others; try a different one

## Advanced Usage

### Customizing Models

Edit the model files to use different versions:

```python
# In openai_model.py
OpenAIModel(api_key, model_name="gpt-4")  # Use GPT-4

# In anthropic_model.py  
AnthropicModel(api_key, model_name="claude-3-opus-20240229")  # Use Opus
```

### Using as a Library

Import and use in your own Python code:

```python
from main import MultiModelAssistant

# Initialize
assistant = MultiModelAssistant()

# Generate response
response = assistant.chat("openai", "What is Python?")
print(response)
```

## API Key Links

Quick access to get your API keys:

- [OpenAI API Keys](https://platform.openai.com/api-keys)
- [Anthropic Console](https://console.anthropic.com/)
- [Google AI Studio](https://makersuite.google.com/app/apikey)
- [Cohere Dashboard](https://dashboard.cohere.com/api-keys)
- [Hugging Face Tokens](https://huggingface.co/settings/tokens)

## Support

For issues or questions:
- Check the main README.md file
- Review this usage guide
- Open an issue on GitHub
