"""
==============================================================================
Test Sentiment Model on Triton (via KServe)
==============================================================================
What:  Sends text to the sentiment model running on Triton and shows results.
       Handles tokenization locally (this is how production systems work —
       the backend service tokenizes, then sends tokens to the model server).

Usage:
    python test-sentiment.py "This product is absolutely wonderful!"
    python test-sentiment.py   # Uses default test texts
==============================================================================
"""

import sys
import json
import numpy as np
import requests
from transformers import AutoTokenizer

# ---- Configuration ----
TRITON_URL = "http://localhost:8085"
MODEL_NAME = "sentiment-onnx"
MAX_SEQ_LEN = 128
TOKENIZER_NAME = "distilbert-base-uncased-finetuned-sst-2-english"
LABELS = ["NEGATIVE", "POSITIVE"]


def predict(text: str, tokenizer, url: str = TRITON_URL):
    """
    Full pipeline:
      1. Tokenize text locally
      2. Send token IDs to Triton via KServe v2 API
      3. Parse logits → softmax → label
    """
    # Step 1: Tokenize
    tokens = tokenizer(
        text,
        padding="max_length",
        max_length=MAX_SEQ_LEN,
        truncation=True,
        return_tensors="np",
    )

    input_ids = tokens["input_ids"].astype(np.int64)
    attention_mask = tokens["attention_mask"].astype(np.int64)

    # Step 2: Send to Triton (KServe v2 inference protocol)
    payload = {
        "inputs": [
            {
                "name": "input_ids",
                "shape": list(input_ids.shape),
                "datatype": "INT64",
                "data": input_ids.flatten().tolist(),
            },
            {
                "name": "attention_mask",
                "shape": list(attention_mask.shape),
                "datatype": "INT64",
                "data": attention_mask.flatten().tolist(),
            },
        ]
    }

    response = requests.post(
        f"{url}/v2/models/{MODEL_NAME}/infer",
        json=payload,
        headers={"Content-Type": "application/json"},
    )

    if response.status_code != 200:
        print(f"  ❌ Error: HTTP {response.status_code}")
        print(f"  {response.text}")
        return None

    # Step 3: Parse response
    result = response.json()
    logits = np.array(result["outputs"][0]["data"]).reshape(-1, 2)

    # Softmax
    probs = np.exp(logits) / np.sum(np.exp(logits), axis=1, keepdims=True)
    pred_class = np.argmax(probs, axis=1)[0]
    confidence = probs[0][pred_class]

    return {
        "text": text,
        "label": LABELS[pred_class],
        "confidence": float(confidence),
        "scores": {
            "NEGATIVE": float(probs[0][0]),
            "POSITIVE": float(probs[0][1]),
        },
    }


def main():
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

    print("=" * 60)
    print("  Sentiment Analysis - Triton on KServe")
    print("=" * 60)
    print()

    # Load tokenizer
    print("[*] Loading tokenizer...")
    try:
        tokenizer = AutoTokenizer.from_pretrained("model-repo/tokenizer")
        print("   Loaded from local cache")
    except Exception:
        print(f"   Downloading from HuggingFace ({TOKENIZER_NAME})...")
        tokenizer = AutoTokenizer.from_pretrained(TOKENIZER_NAME)
    print()

    # Get texts to analyze
    if len(sys.argv) > 1:
        texts = [" ".join(sys.argv[1:])]
    else:
        texts = [
            "This movie is absolutely fantastic! Best film I've seen this year.",
            "Terrible product. Broke after one day. Complete waste of money.",
            "The food was okay. Nothing special but not bad either.",
            "I love this new phone! The camera quality is incredible.",
            "Worst customer service ever. They were so rude and unhelpful.",
            "The weather today is nice and sunny.",
        ]

    # Run predictions
    print("[*] Sending predictions to Triton...")
    print(f"   URL: {TRITON_URL}/v2/models/{MODEL_NAME}/infer")
    print()

    for text in texts:
        result = predict(text, tokenizer)

        if result:
            bar_len = int(result["confidence"] * 30)
            bar = "#" * bar_len + "-" * (30 - bar_len)

            print(f'  >> "{text}"')
            print(f"  => {result['label']}  [{bar}] {result['confidence']:.1%}")
            print(f"     POSITIVE: {result['scores']['POSITIVE']:.4f}  |  NEGATIVE: {result['scores']['NEGATIVE']:.4f}")
            print()

    print("=" * 60)
    print("  ✅ Done!")
    print()
    print("  How this worked:")
    print("    1. Tokenizer (local) converted text → token IDs")
    print("    2. Token IDs sent to Triton via HTTP POST")
    print("    3. Triton ran ONNX model → returned logits")
    print("    4. We applied softmax → got POSITIVE/NEGATIVE")
    print("=" * 60)


if __name__ == "__main__":
    main()
