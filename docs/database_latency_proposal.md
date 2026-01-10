# Proposal to Port Smallest AI Model for Latency Trial in Beast Automation Engine

## Overview

To validate the 60ms database latency in our "Beast" automation setup, we propose porting the smallest available AI model from our list to Nx/Elixir for a trial run. This will allow us to test the end-to-end performance without committing to larger, more resource-intensive models initially.

## Selecting the Smallest Model

From our available models:
- Qwen-3VL (lightweight vision-language model)
- SAM (segmentation model)
- Other options

We'll start with **Qwen-3VL**, as it's suitable for classification and basic inference tasks with manageable resource requirements.

## Porting Process

1. **Adapt the existing Livebook script** (`qwen3vl_inference.exs`) to work within our Elixir application.
2. **Integrate with Oban** for job queuing and background processing.
3. **Test latency impact** using the 60ms remote database connection.

## Expected Latency Impact

With Qwen-3VL's capabilities, inference times should be:
- Classification: ~300-600ms
- Basic generation: ~2-4 seconds

This keeps the trial manageable while testing our optimization strategies.

## Optimization Strategies

### A. Connection Pool Adjustment
```elixir
# config/runtime.exs
config :my_app, MyApp.Repo,
  pool_size: 15  # Moderate increase for trial
```

### B. Batch Processing
Use `Oban.insert_all` for logging model outputs efficiently.

### C. Async Responses
Ensure Discord replies happen before model inference.

## Trial Goals

- Confirm 60ms latency doesn't bottleneck small model performance
- Establish baseline for scaling to larger models
- Validate the "safety buffer" concept in practice

## Summary

Porting Qwen-3VL will provide a low-risk way to trial our latency-tolerant architecture. The model's capabilities ensure useful functionality, while the database optimizations prepare us for heavier workloads.

**Ready to proceed with the port and trial?**
