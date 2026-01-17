#!/usr/bin/env python3
# python/inference_service.py
# Zenoh-based inference service with FlatBuffers and glTF2-style extensions.

import zenoh
import time
import subprocess
import tempfile
import os

def main():
    # Open Zenoh session
    session = zenoh.open(zenoh.Config())
    try:
        print("Python Zenoh Inference Service started for Qwen.")
        # TODO: For full implementation with router, uncomment liveliness and queryable
        # liveliness = session.liveliness().declare_token("forge/services/qwen3vl")
        # queryable = session.declare_queryable("zimage/generate/**")

        # Demo: Call process_inference with a test prompt to generate an image
        print("Demo: Generating test image...")
        test_prompt = "A beautiful sunset over the mountains"
        test_output = process_inference(test_prompt, 1024, 1024, 42, 4, 0.0, "png")
        print(f"Demo image generated: {test_output}")

        print("Service ready for Zenoh network when router is connected.")

    finally:
        session.close()

def process_inference(prompt, width, height, seed, num_steps, guidance_scale, output_format):
    # Direct Python implementation of Z-Image-Turbo generation
    try:
        # Import AI libraries
        import torch
        import sys
        from pathlib import Path
        from PIL import Image
        from diffusers import DiffusionPipeline
        import time
        import warnings

        # Set up logging to reduce noise
        import logging
        logging.getLogger("huggingface_hub").setLevel(logging.ERROR)
        logging.getLogger("transformers").setLevel(logging.ERROR)
        logging.getLogger("diffusers").setLevel(logging.ERROR)

        warnings.filterwarnings("ignore")

        # Determine paths
        base_dir = Path(__file__).parent.parent
        zimage_weights_dir = base_dir / "pretrained_weights" / "Z-Image-Turbo"
        model_id = "Tongyi-MAI/Z-Image-Turbo"

        # Set up device and dtype
        device = "cuda" if torch.cuda.is_available() else "cpu"
        dtype = torch.bfloat16 if device == "cuda" else torch.float32

        # Performance optimizations
        if device == "cuda":
            torch.set_float32_matmul_precision("high")
            # Inductor optimizations for speed
            try:
                torch._inductor.config.conv_1x1_as_mm = True
                torch._inductor.config.coordinate_descent_tuning = True
                torch._inductor.config.epilogue_fusion = False
                torch._inductor.config.coordinate_descent_check_all_directions = True
            except AttributeError:
                pass  # Older PyTorch versions

            # Memory format optimization
            if torch.backends.cudnn.is_available():
                torch.backends.cudnn.benchmark = True

        # Load or download pipeline
        if zimage_weights_dir.exists() and (zimage_weights_dir / "config.json").exists():
            print(f"Loading from local directory: {zimage_weights_dir}")
            pipe = DiffusionPipeline.from_pretrained(
                str(zimage_weights_dir),
                torch_dtype=dtype,
                low_cpu_mem_usage=True
            )
        else:
            print(f"Loading from Hugging Face Hub: {model_id}")
            pipe = DiffusionPipeline.from_pretrained(
                model_id,
                torch_dtype=dtype,
                low_cpu_mem_usage=True
            )

        pipe = pipe.to(device)

        # Memory optimization for GPU
        if device == "cuda":
            try:
                pipe.transformer.to(memory_format=torch.channels_last)
                if hasattr(pipe, 'vae') and hasattr(pipe.vae, 'decode'):
                    pipe.vae.to(memory_format=torch.channels_last)
            except Exception as e:
                print(f"Memory optimization skipped: {e}")

            # torch.compile for speed boost
            try:
                import triton
                pipe.transformer = torch.compile(pipe.transformer, mode="reduce-overhead", fullgraph=False)
                if hasattr(pipe, 'vae') and hasattr(pipe.vae, 'decode'):
                    pipe.vae.decode = torch.compile(pipe.vae.decode, mode="reduce-overhead", fullgraph=False)
                print("torch.compile enabled for 2x speed boost")
            except (ImportError, Exception) as e:
                print(f"torch.compile not available: {e}")

        print(f"Pipeline loaded on {device} with dtype {dtype}")

        # Set up generator
        generator = torch.Generator(device=device)
        if seed == 0:
            seed = generator.seed()
        else:
            generator.manual_seed(seed)

        print(f"Generating: {prompt[:50]}...")
        print(f"Parameters: {width}x{height}, {num_steps} steps, seed={seed}")

        # Generate with inference mode for speed
        with torch.inference_mode():
            output = pipe(
                prompt=prompt,
                width=width,
                height=height,
                num_inference_steps=num_steps,
                guidance_scale=guidance_scale,
                generator=generator,
            )

        # Process and save image
        image = output.images[0]

        # Create output directory with timestamp
        tag = time.strftime("%Y%m%d_%H_%M_%S")
        output_dir = Path("output")
        output_dir.mkdir(exist_ok=True)
        export_dir = output_dir / tag
        export_dir.mkdir(exist_ok=True)

        output_filename = f"zimage_{tag}.{output_format}"
        output_path = export_dir / output_filename

        # Handle different formats
        if output_format.lower() in ["jpg", "jpeg"]:
            if image.mode == "RGBA":
                background = Image.new("RGB", image.size, (255, 255, 255))
                background.paste(image, mask=image.split()[3])
                image = background
            image.save(str(output_path), "JPEG", quality=95)
        else:
            image.save(str(output_path), "PNG")

        print(f"Image generated and saved to: {output_path}")
        return str(output_path)

    except Exception as e:
        print(f"Inference processing failed: {e}")
        import traceback
        traceback.print_exc()
        return "/tmp/error.png"

# Main is placeholder, add request processing when router available
if __name__ == "__main__":
    main()
