import os
import csv

def extract_bitrate(file_path):
    bitrates = []

    with open(file_path, 'r') as file:
        for line in file:
            if "sender" in line or "receiver" in line:
                parts = line.split()
                try:
                    gbits_index = parts.index("Gbits/sec")
                    bitrate = float(parts[gbits_index - 1])  # Extract the numeric value
                    bitrates.append(bitrate)
                except ValueError:
                    continue

    # Calculate average
    avg_bitrate = sum(bitrates) / len(bitrates) if bitrates else 0

    return avg_bitrate

def extract_bitrate_from_directory(directory_path):
    results = {}

    for root, dirs, files in os.walk(directory_path):
        # Check if the directory has no subdirectories
        if not dirs:
            subdir_name = os.path.relpath(root, directory_path)  # Relative subdirectory name
            if subdir_name == ".":
                subdir_name = "root"  # Handle the root directory case

            results[subdir_name] = {}
            for file_name in files:
                file_path = os.path.join(root, file_name)
                if os.path.isfile(file_path):  # Ensure it's a file
                    avg_bitrate = extract_bitrate(file_path)
                    results[subdir_name][file_name] = avg_bitrate

    return results

def write_results_to_csv(results, output_csv_path):
    # Collect all unique file names
    all_files = set()
    for subdir_results in results.values():
        all_files.update(subdir_results.keys())

    all_files = sorted(all_files)  # Sort file names for consistent ordering

    # Write to CSV
    with open(output_csv_path, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)

        # Write header
        header = ["File Name"] + list(results.keys())
        writer.writerow(header)

        # Write rows
        for file_name in all_files:
            row = [file_name]
            for subdir_name in results.keys():
                row.append(results[subdir_name].get(file_name, 0))  # Default to 0 if no bitrate
            writer.writerow(row)

# Replace with your directory path
directory_path = "/tmp/iperf_report/"
output_csv_path = "/tmp/iperf_results.csv"

results = extract_bitrate_from_directory(directory_path)
write_results_to_csv(results, output_csv_path)

print(f"Results written to {output_csv_path}")
