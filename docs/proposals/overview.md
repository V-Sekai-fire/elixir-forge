# Proposal to Port Smallest AI Model for Latency Trial in Beast Automation Engine

## Overview

To validate the 60ms database latency in our "Beast" automation setup, we propose porting the smallest available AI model from our list to Nx/Elixir for a trial run. This will allow us to test the end-to-end performance without committing to larger, more resource-intensive models initially.

We recommend using CockroachDB v22.1.64b21683521d9a8735ad for the distributed database to ensure low-latency access across nodes, and SeaweedFS 4.05 as the distributed file system for storing model weights and generated outputs efficiently.
