# Contributing to X Miner

Thank you for your interest in contributing to X! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)

## Code of Conduct

By participating in this project, you agree to:
- Be respectful and inclusive
- Focus on constructive feedback
- Accept differing viewpoints and experiences
- Prioritize the community's best interests

## How Can I Contribute?

### Types of Contributions

We welcome various types of contributions:

1. **Bug Fixes** - Fix issues in the existing codebase
2. **Performance Improvements** - Optimize algorithms and code
3. **New Features** - Implement items from the roadmap (see `todo.md`)
4. **Documentation** - Improve or add documentation
5. **Testing** - Add tests, report test results on different platforms
6. **Code Review** - Review pull requests from other contributors

### Good First Issues

If you're new to the project, look for issues tagged with:
- `good first issue` - Beginner-friendly tasks
- `help wanted` - Tasks where we need assistance
- `documentation` - Documentation improvements

## Development Setup

### Prerequisites

See [BUILD.md](BUILD.md) for detailed build requirements and instructions.

### Quick Start

```bash
# Clone the repository
git clone https://github.com/ktheindifferent/X
cd X

# Create a development build
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)

# Run tests (when available)
make test
```

### Development Build Options

For development, use debug builds with additional checks:

```bash
cmake .. \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_C_FLAGS="-Wall -Wextra -Werror" \
  -DCMAKE_CXX_FLAGS="-Wall -Wextra -Werror" \
  -DWITH_DEBUG_LOG=ON
```

## Coding Standards

### Code Style

X uses a consistent code style enforced by automated tools:

- **Clang-Format** - Automatic code formatting
- **Clang-Tidy** - Static analysis
- **EditorConfig** - Editor-agnostic style settings

#### Formatting Your Code

Before submitting, format your code:

```bash
# Format a specific file
clang-format -i src/path/to/file.cpp

# Format all changed files
git diff --name-only --diff-filter=ACMR | grep -E '\.(cpp|h|hpp)$' | xargs clang-format -i
```

#### Running Static Analysis

```bash
# Run clang-tidy on your changes
clang-tidy src/path/to/file.cpp -- -Isrc -I/usr/local/include
```

### General Guidelines

1. **Keep It Simple** - Avoid over-engineering
2. **Comment When Needed** - Explain complex logic, not obvious code
3. **Error Handling** - Always handle errors appropriately
4. **Security First** - Avoid vulnerabilities (buffer overflows, injection, etc.)
5. **Performance Matters** - This is mining software; performance is critical
6. **Cross-Platform** - Test on multiple platforms when possible

### C++ Guidelines

- Use C++14 standard (current project requirement)
- Prefer `const` and `constexpr` where applicable
- Use RAII for resource management
- Avoid raw pointers; use smart pointers when needed
- Use meaningful variable and function names
- Keep functions focused and concise

### Naming Conventions

```cpp
class MyClass;              // CamelCase for classes
void myFunction();          // camelBack for functions
int myVariable;             // camelBack for variables
const int MY_CONSTANT = 1;  // UPPER_CASE for constants
namespace xmrig { }         // lower_case for namespaces
```

### File Structure

```cpp
/* X Miner
 * Copyright (c) 2025 X Project
 *
 * [License header]
 */

#include "header.h"          // Own header first
#include "project/headers.h" // Project headers
#include <system/headers.h>  // System headers

namespace xmrig {

// Implementation

} // namespace xmrig
```

## Submitting Changes

### Workflow

1. **Fork the Repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/X
   cd X
   git remote add upstream https://github.com/ktheindifferent/X
   ```

2. **Create a Feature Branch**
   ```bash
   git checkout -b feature/my-awesome-feature
   # or
   git checkout -b fix/bug-description
   ```

3. **Make Your Changes**
   - Write clean, well-documented code
   - Follow the coding standards
   - Add tests if applicable

4. **Test Your Changes**
   ```bash
   # Build and test
   mkdir build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Debug
   make -j$(nproc)

   # Test basic functionality
   ./x --version
   ./x --help
   ./x --bench=1M  # Run benchmark
   ```

5. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "Add feature: description of feature"
   ```

   **Commit Message Guidelines:**
   - Use present tense ("Add feature" not "Added feature")
   - Be concise but descriptive
   - Reference issues: "Fix #123: description"
   - For larger changes, add details in commit body

6. **Push to Your Fork**
   ```bash
   git push origin feature/my-awesome-feature
   ```

7. **Create a Pull Request**
   - Go to GitHub and create a pull request
   - Fill out the PR template
   - Link related issues
   - Describe your changes clearly

### Pull Request Guidelines

- **One Feature Per PR** - Keep PRs focused
- **Update Documentation** - If adding features, update relevant docs
- **Add Tests** - Include tests for new functionality
- **Check CI** - Ensure all CI checks pass
- **Respond to Feedback** - Address review comments promptly
- **Keep It Updated** - Rebase on latest main if needed

### PR Title Format

```
Add: New feature description
Fix: Bug description
Update: Component being updated
Refactor: Code being refactored
Docs: Documentation changes
Performance: Optimization description
```

## Reporting Bugs

### Before Reporting

1. **Search Existing Issues** - Check if already reported
2. **Update to Latest** - Verify the bug exists in latest version
3. **Minimal Reproduction** - Create minimal steps to reproduce

### Bug Report Template

```markdown
**Describe the bug**
A clear description of the bug.

**To Reproduce**
Steps to reproduce:
1. Build with...
2. Run with config...
3. See error

**Expected behavior**
What you expected to happen.

**Actual behavior**
What actually happened.

**Environment:**
- OS: [e.g., Ubuntu 22.04, Windows 11, macOS 14]
- X Version: [e.g., 1.0.0]
- Compiler: [e.g., GCC 11.4, Clang 15, MSVC 2022]
- Hardware: [CPU/GPU model]

**Additional context**
- Configuration file
- Full error messages
- Relevant logs
- Screenshots if applicable
```

## Suggesting Enhancements

We welcome feature suggestions! Before suggesting:

1. **Check the Roadmap** - See `todo.md` for planned features
2. **Search Issues** - Check if already suggested
3. **Consider Scope** - Does it fit the project goals?

### Enhancement Template

```markdown
**Is your feature related to a problem?**
Describe the problem or limitation.

**Describe the solution**
Clear description of the proposed feature.

**Describe alternatives**
Other solutions you've considered.

**Additional context**
- Use cases
- Benefits
- Implementation ideas
```

## Performance Contributions

Since X is mining software, performance is critical:

1. **Benchmark Before/After** - Measure improvements
2. **Profile Your Code** - Use profiling tools
3. **Test on Multiple Platforms** - Performance varies by platform
4. **Document Gains** - Show concrete numbers in PR

### Benchmarking

```bash
# Run benchmark before changes
./x --bench=10M --cpu-no-yield > before.txt

# Make changes, rebuild

# Run benchmark after changes
./x --bench=10M --cpu-no-yield > after.txt

# Compare results
diff before.txt after.txt
```

## Algorithm Contributions

When adding or optimizing mining algorithms:

1. **Reference Implementation** - Link to algorithm specification
2. **Test Vectors** - Include test cases with expected outputs
3. **Cross-Platform Testing** - Test on x86, ARM, etc.
4. **SIMD Optimizations** - Consider SSE, AVX, NEON variants
5. **Memory Usage** - Document memory requirements

## Documentation Contributions

Documentation is as important as code:

- **Keep It Updated** - Update docs when changing features
- **Be Clear** - Write for users of varying experience levels
- **Examples** - Include practical examples
- **Screenshots** - Add visuals where helpful

## Questions?

- **Documentation**: See README.md, BUILD.md, and docs in `/doc`
- **Chat**: (To be set up - Discord/Telegram)
- **Issues**: Use GitHub issues for questions
- **Roadmap**: Check `todo.md` for project direction

## Attribution

Contributors will be recognized in:
- GitHub contributors page
- Release notes for significant contributions
- Project documentation for major features

Thank you for contributing to X! Every contribution, no matter how small, helps make the project better.
