const std = @import("std");

pub const GenerateError = error{
    UnsupportedShell,
};

pub fn generate(writer: anytype, shell: []const u8) (GenerateError || @TypeOf(writer).Error)!void {
    if (std.mem.eql(u8, shell, "bash")) {
        try generateBash(writer);
    } else if (std.mem.eql(u8, shell, "zsh")) {
        try generateZsh(writer);
    } else if (std.mem.eql(u8, shell, "fish")) {
        try generateFish(writer);
    } else {
        return GenerateError.UnsupportedShell;
    }
}

fn generateBash(writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeAll(
        \\_nanogen_completions() {
        \\    local cur prev opts
        \\    COMPREPLY=()
        \\    cur="${COMP_WORDS[COMP_CWORD]}"
        \\    prev="${COMP_WORDS[COMP_CWORD-1]}"
        \\    opts="--prompt --file --model --aspect-ratio --image-size --output --completions --no-open --verbose --version --help -p -f -o -v -h"
        \\
        \\    case "${prev}" in
        \\        --aspect-ratio)
        \\            COMPREPLY=( $(compgen -W "16:9 4:3 1:1 9:16" -- "${cur}") )
        \\            return 0
        \\            ;;
        \\        --image-size)
        \\            COMPREPLY=( $(compgen -W "2K 4K" -- "${cur}") )
        \\            return 0
        \\            ;;
        \\        --completions)
        \\            COMPREPLY=( $(compgen -W "bash zsh fish" -- "${cur}") )
        \\            return 0
        \\            ;;
        \\        --file|-f)
        \\            COMPREPLY=( $(compgen -f -- "${cur}") )
        \\            return 0
        \\            ;;
        \\        --output|-o)
        \\            COMPREPLY=( $(compgen -d -- "${cur}") )
        \\            return 0
        \\            ;;
        \\        --prompt|-p|--model)
        \\            return 0
        \\            ;;
        \\    esac
        \\
        \\    if [[ "${cur}" == -* ]]; then
        \\        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        \\        return 0
        \\    fi
        \\}
        \\
        \\complete -F _nanogen_completions nanogen
        \\
    );
}

fn generateZsh(writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeAll(
        \\#compdef nanogen
        \\
        \\_nanogen() {
        \\    _arguments \
        \\        '(-p --prompt)'{-p,--prompt}'[Generation prompt]:text: ' \
        \\        '(-f --file)'{-f,--file}'[Read prompt from file]:file:_files' \
        \\        '--model[Model name]:name: ' \
        \\        '--aspect-ratio[Aspect ratio]:ratio:(16\:9 4\:3 1\:1 9\:16)' \
        \\        '--image-size[Image size]:size:(2K 4K)' \
        \\        '(-o --output)'{-o,--output}'[Output directory]:dir:_directories' \
        \\        '--completions[Generate shell completion]:shell:(bash zsh fish)' \
        \\        '--no-open[Do not auto-open generated image]' \
        \\        '(-v --verbose)'{-v,--verbose}'[Enable debug logging]' \
        \\        '--version[Show version]' \
        \\        '(-h --help)'{-h,--help}'[Show this help]'
        \\}
        \\
        \\_nanogen "$@"
        \\
    );
}

fn generateFish(writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeAll(
        \\# nanogen completions for fish
        \\complete -c nanogen -e
        \\complete -c nanogen -s p -l prompt -d 'Generation prompt' -x
        \\complete -c nanogen -s f -l file -d 'Read prompt from file' -r -F
        \\complete -c nanogen -l model -d 'Model name' -x
        \\complete -c nanogen -l aspect-ratio -d 'Aspect ratio' -x -a '16:9 4:3 1:1 9:16'
        \\complete -c nanogen -l image-size -d 'Image size' -x -a '2K 4K'
        \\complete -c nanogen -s o -l output -d 'Output directory' -r -a '(__fish_complete_directories)'
        \\complete -c nanogen -l completions -d 'Generate shell completion' -x -a 'bash zsh fish'
        \\complete -c nanogen -l no-open -d 'Do not auto-open generated image'
        \\complete -c nanogen -s v -l verbose -d 'Enable debug logging'
        \\complete -c nanogen -l version -d 'Show version'
        \\complete -c nanogen -s h -l help -d 'Show this help'
        \\
    );
}

// Tests

test "generate bash" {
    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try generate(stream.writer(), "bash");
    const output = stream.getWritten();
    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "complete -F _nanogen_completions nanogen") != null);
}

test "generate zsh" {
    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try generate(stream.writer(), "zsh");
    const output = stream.getWritten();
    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "#compdef nanogen") != null);
}

test "generate fish" {
    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try generate(stream.writer(), "fish");
    const output = stream.getWritten();
    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "complete -c nanogen") != null);
}

test "unsupported shell" {
    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const result = generate(stream.writer(), "powershell");
    try std.testing.expectError(GenerateError.UnsupportedShell, result);
}
