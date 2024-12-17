# Terraform Security Ignore Script

This script automates the process of handling `tfsec` findings by adding ignore comments directly into Terraform files. It allows you to start with a clean state and incrementally fix security issues while ensuring new issues are not introduced.

## How It Works

1. **Run `tfsec` Security Checks**: The script runs `tfsec` on the specified Terraform directory.
2. **Parse Findings**: It parses the `tfsec` output and identifies problematic files and lines.
3. **Insert Ignore Comments**: It inserts `#tfsec:ignore:<rule>` comments directly into the relevant Terraform files.
4. **Batch Insertion**: All findings are processed, and insertions are applied from the bottom of the file upwards, ensuring line numbers are preserved.

By including `tfsec` in your CI/CD pipeline, you can prevent new issues from being introduced after applying this script.

---

## Installation

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/yourusername/tfsec-ignore-script.git
   cd tfsec-ignore-script
   ```

2. **Make the Script Executable:**
   ```bash
   chmod +x insert_tfsec_ignores.sh
   ```

3. **Ensure `tfsec` Is Installed:**
   ```bash
   brew install tfsec    # For macOS
   sudo apt install tfsec  # For Linux
   ```

---

## Usage

### Running the Script

```bash
./insert_tfsec_ignores.sh /path/to/terraform/code
```

- Replace `/path/to/terraform/code` with the directory containing your Terraform files.

### Example:

```bash
./insert_tfsec_ignores.sh ./terraform
```

---

## How to Integrate with CI/CD

1. **Run `tfsec` in CI/CD:**
   Add the following steps to your CI/CD pipeline configuration:

   ```yaml
   steps:
     - name: Run tfsec
       run: |
         tfsec ./terraform
   ```

2. **Prevent New Issues:**
   The script ensures all current issues are ignored while enabling `tfsec` checks for new ones.

---

## Best Practices

1. **Incremental Fixes:**
   - After running the script, fix issues one by one.
   - Remove corresponding ignore comments once an issue is resolved.

2. **Pipeline Integration:**
   - Use `tfsec` as a mandatory security check.
   - Block merges if `tfsec` reports new findings.

---

## Troubleshooting

- **File Not Found Warnings:** Ensure that the specified path exists and that you have correct permissions.
- **Incorrect Insertion:** Check the inserted comments using `git diff` after running the script.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

## Contributing

Contributions are welcome! Please submit issues and pull requests for improvements or additional features.

---

## Acknowledgments

- Inspired by security best practices for Terraform infrastructure.
- Powered by `tfsec` for detecting and fixing security issues.

Happy Securing! 🚀


