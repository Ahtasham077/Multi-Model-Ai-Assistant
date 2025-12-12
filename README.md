# Multi-Model AI Assistant 🤖

A powerful and flexible AI assistant that integrates with five major AI platforms, allowing you to interact with different AI models from a single interface. Perfect for comparing responses, testing different models, or integrating multiple AI capabilities into your business workflows.

## 🌟 Features

- **Multi-Model Support**: Integrate with 5 major AI platforms:
  - OpenAI (GPT-3.5/GPT-4)
  - Anthropic (Claude)
  - Google (Gemini)
  - Cohere
  - Hugging Face

- **Easy Model Selection**: Switch between different AI models seamlessly
- **Interactive CLI**: User-friendly command-line interface with colored output
- **Flexible Configuration**: Simple environment-based API key management
- **Error Handling**: Robust error handling for API failures
- **Extensible Architecture**: Easy to add new models or customize existing ones

## 📋 Prerequisites

- Python 3.7 or higher
- API keys for the AI services you want to use (at least one required)

## 🚀 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Ahtasham077/Multi-Model-Ai-Assistant.git
   cd Multi-Model-Ai-Assistant
   ```

2. **Create a virtual environment (recommended)**
   ```bash
   python -m venv venv
   
   # On Windows
   venv\Scripts\activate
   
   # On macOS/Linux
   source venv/bin/activate
   ```

3. **Install required dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up your API keys**
   
   Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
   
   Edit the `.env` file and add your API keys:
   ```
   OPENAI_API_KEY=your_openai_api_key_here
   ANTHROPIC_API_KEY=your_anthropic_api_key_here
   GOOGLE_API_KEY=your_google_api_key_here
   COHERE_API_KEY=your_cohere_api_key_here
   HUGGINGFACE_API_KEY=your_huggingface_api_key_here
   ```

## 🔑 Getting API Keys

- **OpenAI**: [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)
- **Anthropic**: [https://console.anthropic.com/](https://console.anthropic.com/)
- **Google Gemini**: [https://makersuite.google.com/app/apikey](https://makersuite.google.com/app/apikey)
- **Cohere**: [https://dashboard.cohere.com/api-keys](https://dashboard.cohere.com/api-keys)
- **Hugging Face**: [https://huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)

**Note**: You don't need all API keys. The assistant will work with whichever models you configure.

## 💻 Usage

### Running the Interactive Assistant

Simply run the main application:

```bash
python main.py
```

### Interactive Mode

1. The assistant will display all available models based on your configured API keys
2. Select a model by entering its number (1-5)
3. Type your message/prompt
4. Receive a response from the selected AI model
5. You can switch models, continue chatting, or quit anytime

### Example Session

```
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
You: What is artificial intelligence?

🤖 OpenAI gpt-3.5-turbo is thinking...

OpenAI gpt-3.5-turbo: 
Artificial intelligence (AI) is the simulation of human intelligence...
```

## 🏗️ Project Structure

```
Multi-Model-Ai-Assistant/
├── main.py                 # Main application entry point
├── base_model.py          # Abstract base class for AI models
├── openai_model.py        # OpenAI integration
├── anthropic_model.py     # Anthropic/Claude integration
├── gemini_model.py        # Google Gemini integration
├── cohere_model.py        # Cohere integration
├── huggingface_model.py   # Hugging Face integration
├── requirements.txt       # Python dependencies
├── .env.example          # Example environment variables
├── .gitignore            # Git ignore file
└── README.md             # This file
```

## 🔧 Customization

### Adding a New Model

1. Create a new file (e.g., `newmodel_model.py`)
2. Inherit from `AIModel` base class
3. Implement required methods: `generate_response()` and `get_model_name()`
4. Add the model to `MultiModelAssistant.__init__()` in `main.py`

### Changing Default Models

Edit the model initialization in each model file to use different versions:
```python
# In openai_model.py
OpenAIModel(api_key, model_name="gpt-4")  # Use GPT-4 instead

# In anthropic_model.py
AnthropicModel(api_key, model_name="claude-3-opus-20240229")  # Use Opus
```

## 🤝 Use Cases

- **Model Comparison**: Test the same prompt across different AI models
- **Business Integration**: Integrate multiple AI capabilities into your workflows
- **Development Testing**: Test your prompts before production deployment
- **AI Research**: Compare responses from different models for research
- **Cost Optimization**: Use cheaper models for simple tasks, advanced models for complex ones

## 📝 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

- OpenAI for GPT models
- Anthropic for Claude
- Google for Gemini
- Cohere for their language models
- Hugging Face for their model hub and inference API

## 📞 Support

For issues, questions, or contributions, please open an issue on GitHub.

---

**Happy AI Chatting! 🚀**
