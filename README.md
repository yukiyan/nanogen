# nanogen

Nanobanana image generation CLI tool. A fast, lightweight single binary written in Zig.

## Features

- Image generation using the Gemini API (nanobanana)
- Zero external dependencies, pure Zig implementation
- ~750KB statically linked binary
- XDG Base Directory compliant

## Requirements

- [Zig](https://ziglang.org/) 0.15.2
- Gemini API key

## Installation

### mise

```bash
mise use -g github:yukiyan/nanogen
```

### GitHub Releases

Download binaries from [GitHub Releases](https://github.com/yukiyan/nanogen/releases).

### From source

```bash
zig build -Doptimize=ReleaseSmall
cp zig-out/bin/nanogen ~/.local/bin/
```

## Quick Start

```bash
# Generate an image
export NANOGEN_API_KEY="your-api-key"
nanogen -p "Mt. Fuji at sunset"
```

## Usage

```
Usage: nanogen [OPTIONS]

Options:
  -p, --prompt <TEXT>         Generation prompt
  -f, --file <PATH>           Read prompt from file
      --model <NAME>          Model name (default: gemini-3-pro-image-preview)
      --aspect-ratio <RATIO>  Aspect ratio (default: 16:9)
                              1:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9
      --image-size <SIZE>     Image size (default: 2K)
                              512, 1K, 2K, 4K
  -o, --output <DIR>          Output directory
      --no-open               Don't auto-open generated image
  -v, --verbose               Enable debug logging
      --version               Show version
  -h, --help                  Show this help
```

### Examples

```bash
# Generate from a text prompt
nanogen -p "a cat sitting on a cloud"

# Read prompt from a file
nanogen -f prompt.txt

# Specify aspect ratio and resolution
nanogen -p "infographic about AI" --aspect-ratio 4:3 --image-size 4K

# Specify output directory and disable auto-open
nanogen -p "sunset" -o /tmp/images --no-open

# Enable debug logging
nanogen -p "hello" -v
```

## Configuration

Configuration is applied in the following order of precedence (highest first):

1. CLI flags
2. Environment variables
3. Config file
4. Default values

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NANOGEN_API_KEY` | API key (required) | - |
| `NANOGEN_MODEL` | Model name | `gemini-3-pro-image-preview` |
| `NANOGEN_ASPECT_RATIO` | Aspect ratio | `16:9` |
| `NANOGEN_IMAGE_SIZE` | Image size | `2K` |
| `NANOGEN_OUTPUT_DIR` | Output directory | `$XDG_DATA_HOME/nanogen` |
| `NANOGEN_AUTO_OPEN` | Auto-open (set `false` or `0` to disable) | `true` |

### Config File

`$XDG_CONFIG_HOME/nanogen/config.json` (default: `~/.config/nanogen/config.json`)

```json
{
  "api_key": "your-api-key",
  "model": "gemini-3-pro-image-preview",
  "aspect_ratio": "16:9",
  "image_size": "2K",
  "output_dir": "/path/to/output",
  "auto_open": true
}
```

## Output

Generated files are saved to `$XDG_DATA_HOME/nanogen/` (default: `~/.local/share/nanogen/`).

```
~/.local/share/nanogen/
├── images/          # Generated PNG images
├── responses/       # API response JSON
└── logs/            # Execution logs
```

## Development

```bash
# Debug build
zig build

# Run tests
zig build test

# Release build (minimum size)
zig build -Doptimize=ReleaseSmall

# Release build (maximum speed)
zig build -Doptimize=ReleaseFast
```

## License

MIT
