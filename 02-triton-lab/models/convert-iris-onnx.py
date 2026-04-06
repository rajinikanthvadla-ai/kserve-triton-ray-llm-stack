# -*- coding: utf-8 -*-
"""
Convert SKLearn Iris Model -> ONNX Format (for Triton)
"""

import os
import numpy as np
from sklearn.datasets import load_iris
from sklearn.linear_model import LogisticRegression
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType

def main():
    print("=" * 50)
    print("  Converting Iris Model -> ONNX")
    print("=" * 50)
    print()

    print("[Step 1] Training Iris classifier...")
    iris = load_iris()
    X, y = iris.data.astype(np.float32), iris.target

    model = LogisticRegression(max_iter=200, random_state=42)
    model.fit(X, y)
    accuracy = model.score(X, y)
    print(f"   Model accuracy: {accuracy:.2%}")
    print()

    print("[Step 2] Converting to ONNX format...")
    initial_type = [("float_input", FloatTensorType([None, 4]))]
    onnx_model = convert_sklearn(
        model,
        initial_types=initial_type,
        target_opset=13,
        options={type(model): {"zipmap": False}},
    )
    print("   DONE - ONNX conversion complete")
    print()

    print("[Step 3] Creating Triton model repository...")
    model_dir = os.path.join("model-repo", "iris-onnx", "1")
    os.makedirs(model_dir, exist_ok=True)

    model_path = os.path.join(model_dir, "model.onnx")
    with open(model_path, "wb") as f:
        f.write(onnx_model.SerializeToString())
    print(f"   Saved: {model_path}")

    # No config.pbtxt needed! Triton auto-detects input/output shapes from ONNX.
    # (strict_model_config=0 enables auto-complete)
    print("   Skipping config.pbtxt (Triton auto-detects from ONNX model)")
    print()

    print("[Step 4] Verifying ONNX model locally...")
    import onnxruntime as ort

    session = ort.InferenceSession(model_path)
    test_input = np.array([[6.8, 2.8, 4.8, 1.4]], dtype=np.float32)
    results = session.run(None, {"float_input": test_input})
    print(f"   Test input:  [6.8, 2.8, 4.8, 1.4]")
    print(f"   Prediction:  {results[0][0]} (0=Setosa, 1=Versicolor, 2=Virginica)")
    print()

    print("=" * 50)
    print("  Iris ONNX model ready!")
    print(f"  Location: model-repo/iris-onnx/")
    print("=" * 50)

if __name__ == "__main__":
    main()
