import logging

from flask import Flask, jsonify, request
from transformers import pipeline

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Initialize model (this happens once when container starts)
logger.info("Loading model...")
generator = pipeline('text-generation', model='distilgpt2')
logger.info("Model loaded successfully")


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy"}), 200


@app.route('/generate', methods=['POST'])
def generate():
    """Generate text based on a prompt"""
    try:
        data = request.get_json()
        prompt = data.get('prompt', '')
        max_length = data.get('max_length', 50)

        if not prompt:
            return jsonify({"error": "No prompt provided"}), 400

        logger.info(f"Generating text for prompt: {prompt[:50]}...")
        result = generator(
            prompt, max_length=max_length, num_return_sequences=1
        )

        return (
            jsonify(
                {"prompt": prompt, "generated_text": result[0]["generated_text"]}
            ),
            200,
        )

    except Exception as e:
        logger.error(f"Error generating text: {str(e)}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)