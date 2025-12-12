#!/usr/bin/env python3
"""
Example script demonstrating programmatic usage of Multi-Model AI Assistant
"""
import os
from main import MultiModelAssistant


def example_basic_usage():
    """Basic usage example"""
    print("=" * 60)
    print("Example 1: Basic Usage")
    print("=" * 60)
    
    # Initialize the assistant
    assistant = MultiModelAssistant()
    
    # Check available models
    if not assistant.available_models:
        print("⚠️  No API keys configured. Please set up .env file.")
        return
    
    # Use the first available model
    model_name = list(assistant.available_models.keys())[0]
    print(f"\nUsing model: {model_name}")
    
    # Generate a response
    prompt = "What are the three laws of robotics?"
    print(f"\nPrompt: {prompt}")
    response = assistant.chat(model_name, prompt)
    print(f"\nResponse: {response}\n")


def example_compare_models():
    """Compare responses from multiple models"""
    print("=" * 60)
    print("Example 2: Comparing Multiple Models")
    print("=" * 60)
    
    assistant = MultiModelAssistant()
    
    if len(assistant.available_models) < 2:
        print("⚠️  Need at least 2 API keys configured to compare models.")
        return
    
    prompt = "Explain machine learning in one sentence."
    print(f"\nPrompt: {prompt}\n")
    
    # Get responses from all available models
    for model_name, model in assistant.available_models.items():
        print(f"--- {model.get_model_name()} ---")
        response = assistant.chat(model_name, prompt)
        print(f"{response}\n")


def example_with_parameters():
    """Example with custom parameters"""
    print("=" * 60)
    print("Example 3: Using Custom Parameters")
    print("=" * 60)
    
    assistant = MultiModelAssistant()
    
    if not assistant.available_models:
        print("⚠️  No API keys configured.")
        return
    
    model_name = list(assistant.available_models.keys())[0]
    prompt = "Write a haiku about coding."
    
    print(f"\nUsing model: {model_name}")
    print(f"Prompt: {prompt}")
    print("Parameters: temperature=0.9, max_tokens=100\n")
    
    # Generate with custom parameters
    response = assistant.chat(
        model_name, 
        prompt,
        temperature=0.9,  # More creative
        max_tokens=100     # Shorter response
    )
    print(f"Response: {response}\n")


def main():
    """Run all examples"""
    print("\n🤖 Multi-Model AI Assistant - Usage Examples\n")
    
    try:
        example_basic_usage()
        print("\n")
        example_compare_models()
        print("\n")
        example_with_parameters()
    except Exception as e:
        print(f"❌ Error: {e}")
    
    print("=" * 60)
    print("Examples completed!")
    print("=" * 60)


if __name__ == "__main__":
    main()
