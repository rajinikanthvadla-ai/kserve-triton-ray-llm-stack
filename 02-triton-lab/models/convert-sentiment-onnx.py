# -*- coding: utf-8 -*-
"""
Convert DistilBERT Sentiment Model -> ONNX Format (for Triton)
"""

import os
import sys
import io
import numpy as np
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

# Fix Windows encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

MODEL_NAME = "distilbert-base-uncased-finetuned-sst-2-english"
MAX_SEQ_LEN = 128


def main():
    print("=" * 50)
    print("  Converting Sentiment Model -> ONNX")
    print("=" * 50)
    print()

    # Step 1: Download model
    print(f"[Step 1] Downloading {MODEL_NAME}...")
    print("   (Downloads ~260MB on first run)")
    print()

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForSequenceClassification.from_pretrained(MODEL_NAME)
    model.eval()
    print("   DONE - Model and tokenizer loaded")
    print()

    # Step 2: Convert to ONNX
    print("[Step 2] Converting to ONNX format...")

    dummy_text = "This is a sample text for export"
    dummy_tokens = tokenizer(
        dummy_text,
        padding="max_length",
        max_length=MAX_SEQ_LEN,
        truncation=True,
        return_tensors="pt"
    )

    model_dir = os.path.join("model-repo", "sentiment-onnx", "1")
    os.makedirs(model_dir, exist_ok=True)
    model_path = os.path.join(model_dir, "model.onnx")

    # dynamo=False forces legacy exporter (IR version 8, Triton 2.34 max is 9)
    torch.onnx.export(
        model,
        (dummy_tokens["input_ids"], dummy_tokens["attention_mask"]),
        model_path,
        export_params=True,
        opset_version=14,
        input_names=["input_ids", "attention_mask"],
        output_names=["logits"],
        dynamic_axes={
            "input_ids": {0: "batch_size"},
            "attention_mask": {0: "batch_size"},
            "logits": {0: "batch_size"},
        },
        dynamo=False,
    )
    print(f"   Saved: {model_path}")

    model_size_mb = os.path.getsize(model_path) / (1024 * 1024)
    print(f"   Model size: {model_size_mb:.1f} MB")

    # Also check for external data file
    data_file = model_path + ".data"
    if os.path.exists(data_file):
        data_size_mb = os.path.getsize(data_file) / (1024 * 1024)
        print(f"   External data: {data_size_mb:.1f} MB")
    print()

    # NO config.pbtxt — Triton auto-detects from ONNX model
    # (strict_model_config=0 enables auto-complete)
    print("   Skipping config.pbtxt (Triton auto-detects from ONNX)")
    print()

    # Step 3: Save tokenizer
    print("[Step 3] Saving tokenizer locally...")
    tokenizer_dir = os.path.join("model-repo", "tokenizer")
    tokenizer.save_pretrained(tokenizer_dir)
    print(f"   Saved: {tokenizer_dir}/")
    print()

    # Step 4: Verify locally
    print("[Step 4] Verifying ONNX model locally...")
    import onnxruntime as ort

    session = ort.InferenceSession(model_path)
    labels = ["NEGATIVE", "POSITIVE"]

    test_texts = [
        "This movie is absolutely fantastic! I loved every second of it.",
        "Terrible experience. The worst product I have ever bought.",
        "The weather today is okay, nothing special.",
    ]

    for text in test_texts:
        tokens = tokenizer(
            text, padding="max_length", max_length=MAX_SEQ_LEN,
            truncation=True, return_tensors="np",
        )
        logits = session.run(None, {
            "input_ids": tokens["input_ids"].astype(np.int64),
            "attention_mask": tokens["attention_mask"].astype(np.int64),
        })[0]

        probs = np.exp(logits) / np.sum(np.exp(logits), axis=1, keepdims=True)
        pred_class = np.argmax(probs, axis=1)[0]
        confidence = probs[0][pred_class]

        print(f'   "{text[:50]}..."')
        print(f"   -> {labels[pred_class]} ({confidence:.1%})")
        print()

    print("=" * 50)
    print("  Sentiment ONNX model ready!")
    print(f"  Location: model-repo/sentiment-onnx/")
    print("=" * 50)


if __name__ == "__main__":
    main()
