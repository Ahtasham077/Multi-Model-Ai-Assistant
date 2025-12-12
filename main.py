"""
Multi-Model AI Assistant
Main application file
"""
import os
from dotenv import load_dotenv
from colorama import init, Fore, Style
from typing import Dict, Optional

from openai_model import OpenAIModel
from anthropic_model import AnthropicModel
from gemini_model import GeminiModel
from cohere_model import CohereModel
from huggingface_model import HuggingFaceModel
from base_model import AIModel

# Initialize colorama for colored terminal output
init(autoreset=True)


class MultiModelAssistant:
    """Main class for Multi-Model AI Assistant"""
    
    def __init__(self):
        """Initialize the assistant with all available models"""
        # Load environment variables
        load_dotenv()
        
        # Initialize all models
        self.models: Dict[str, AIModel] = {
            "openai": OpenAIModel(os.getenv("OPENAI_API_KEY", "")),
            "anthropic": AnthropicModel(os.getenv("ANTHROPIC_API_KEY", "")),
            "gemini": GeminiModel(os.getenv("GOOGLE_API_KEY", "")),
            "cohere": CohereModel(os.getenv("COHERE_API_KEY", "")),
            "huggingface": HuggingFaceModel(os.getenv("HUGGINGFACE_API_KEY", ""))
        }
        
        # Get available models
        self.available_models = {
            name: model for name, model in self.models.items() 
            if model.is_available()
        }
        
    def list_available_models(self):
        """Display all available models"""
        print(f"\n{Fore.CYAN}{'='*60}")
        print(f"{Fore.CYAN}Available AI Models:")
        print(f"{Fore.CYAN}{'='*60}{Style.RESET_ALL}")
        
        if not self.available_models:
            print(f"{Fore.RED}No models available. Please configure API keys in .env file.{Style.RESET_ALL}")
            return
        
        for i, (name, model) in enumerate(self.available_models.items(), 1):
            print(f"{Fore.GREEN}{i}. {name.upper()}: {model.get_model_name()}{Style.RESET_ALL}")
    
    def get_model_by_number(self, number: int) -> Optional[tuple]:
        """Get model by its number in the list"""
        if 1 <= number <= len(self.available_models):
            return list(self.available_models.items())[number - 1]
        return None
    
    def chat(self, model_name: str, prompt: str, **kwargs) -> str:
        """
        Send a prompt to a specific model and get response
        
        Args:
            model_name: Name of the model to use
            prompt: The prompt/message to send
            **kwargs: Additional parameters
            
        Returns:
            str: Response from the model
        """
        model = self.available_models.get(model_name)
        if not model:
            return f"Error: Model '{model_name}' is not available"
        
        return model.generate_response(prompt, **kwargs)
    
    def run_interactive(self):
        """Run the assistant in interactive mode"""
        print(f"\n{Fore.YELLOW}{'='*60}")
        print(f"{Fore.YELLOW}🤖 Multi-Model AI Assistant 🤖")
        print(f"{Fore.YELLOW}{'='*60}{Style.RESET_ALL}")
        
        if not self.available_models:
            print(f"\n{Fore.RED}❌ No AI models are configured!")
            print(f"{Fore.YELLOW}Please set up your API keys in a .env file.")
            print(f"See .env.example for required keys.{Style.RESET_ALL}")
            return
        
        # Display available models
        self.list_available_models()
        
        # Main interaction loop
        while True:
            print(f"\n{Fore.CYAN}{'='*60}{Style.RESET_ALL}")
            
            # Model selection
            try:
                model_choice = input(f"\n{Fore.YELLOW}Select a model (1-{len(self.available_models)}) or 'q' to quit: {Style.RESET_ALL}")
                
                if model_choice.lower() == 'q':
                    print(f"\n{Fore.GREEN}Thank you for using Multi-Model AI Assistant! Goodbye! 👋{Style.RESET_ALL}")
                    break
                
                model_num = int(model_choice)
                selected_model = self.get_model_by_number(model_num)
                
                if not selected_model:
                    print(f"{Fore.RED}Invalid selection. Please choose a number between 1 and {len(self.available_models)}.{Style.RESET_ALL}")
                    continue
                
                model_name, model = selected_model
                print(f"\n{Fore.GREEN}✓ Selected: {model.get_model_name()}{Style.RESET_ALL}")
                
                # Get user prompt
                print(f"\n{Fore.YELLOW}Enter your message (or 'back' to select another model, 'q' to quit):{Style.RESET_ALL}")
                prompt = input(f"{Fore.WHITE}You: {Style.RESET_ALL}")
                
                if prompt.lower() == 'q':
                    print(f"\n{Fore.GREEN}Thank you for using Multi-Model AI Assistant! Goodbye! 👋{Style.RESET_ALL}")
                    break
                
                if prompt.lower() == 'back':
                    continue
                
                if not prompt.strip():
                    print(f"{Fore.RED}Please enter a message.{Style.RESET_ALL}")
                    continue
                
                # Generate response
                print(f"\n{Fore.BLUE}🤖 {model.get_model_name()} is thinking...{Style.RESET_ALL}")
                response = self.chat(model_name, prompt)
                
                print(f"\n{Fore.GREEN}{model.get_model_name()}: {Style.RESET_ALL}")
                print(f"{Fore.WHITE}{response}{Style.RESET_ALL}")
                
            except ValueError:
                print(f"{Fore.RED}Invalid input. Please enter a number.{Style.RESET_ALL}")
            except KeyboardInterrupt:
                print(f"\n\n{Fore.GREEN}Thank you for using Multi-Model AI Assistant! Goodbye! 👋{Style.RESET_ALL}")
                break
            except Exception as e:
                print(f"{Fore.RED}An error occurred: {str(e)}{Style.RESET_ALL}")


def main():
    """Main entry point"""
    assistant = MultiModelAssistant()
    assistant.run_interactive()


if __name__ == "__main__":
    main()
