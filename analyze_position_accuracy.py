#!/usr/bin/env python3
"""
Position Accuracy Analysis Script
Analyzes CSV log files from the Unity Position Accuracy Logger
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys
import os
from pathlib import Path


def load_log_file(filepath):
    """Load and validate the position accuracy log file"""
    try:
        df = pd.read_csv(filepath)
        required_columns = ['Timestamp', 'VehicleID', 'UnityX', 'UnityZ', 
                          'SumoX', 'SumoZ', 'PositionError', 
                          'LateralError', 'LongitudinalError']
        
        missing_cols = [col for col in required_columns if col not in df.columns]
        if missing_cols:
            print(f"Warning: Missing columns: {missing_cols}")
        
        return df
    except Exception as e:
        print(f"Error loading file: {e}")
        sys.exit(1)


def print_summary_statistics(df):
    """Print summary statistics for all vehicles"""
    print("\n" + "="*70)
    print("OVERALL STATISTICS")
    print("="*70)
    print(f"Total entries: {len(df)}")
    print(f"Number of vehicles: {df['VehicleID'].nunique()}")
    print(f"Simulation duration: {df['Timestamp'].max() - df['Timestamp'].min():.2f} seconds")
    print(f"\nPosition Error Statistics:")
    print(f"  Mean:   {df['PositionError'].mean():.4f} m")
    print(f"  Median: {df['PositionError'].median():.4f} m")
    print(f"  Std:    {df['PositionError'].std():.4f} m")
    print(f"  Min:    {df['PositionError'].min():.4f} m")
    print(f"  Max:    {df['PositionError'].max():.4f} m")
    print(f"  95th percentile: {df['PositionError'].quantile(0.95):.4f} m")


def print_per_vehicle_statistics(df):
    """Print statistics for each vehicle"""
    print("\n" + "="*70)
    print("PER-VEHICLE STATISTICS")
    print("="*70)
    
    for vehicle_id in sorted(df['VehicleID'].unique()):
        vehicle_data = df[df['VehicleID'] == vehicle_id]
        print(f"\n{vehicle_id}:")
        print(f"  Samples: {len(vehicle_data)}")
        print(f"  Position Error:")
        print(f"    Mean:   {vehicle_data['PositionError'].mean():.4f} m")
        print(f"    Max:    {vehicle_data['PositionError'].max():.4f} m")
        print(f"    Std:    {vehicle_data['PositionError'].std():.4f} m")
        print(f"  Lateral Error (mean abs):  {vehicle_data['LateralError'].abs().mean():.4f} m")
        print(f"  Longitudinal Error (mean abs): {vehicle_data['LongitudinalError'].abs().mean():.4f} m")


def plot_position_error_over_time(df, output_dir):
    """Plot position error vs time for all vehicles"""
    plt.figure(figsize=(14, 6))
    
    for vehicle_id in df['VehicleID'].unique():
        vehicle_data = df[df['VehicleID'] == vehicle_id]
        plt.plot(vehicle_data['Timestamp'], vehicle_data['PositionError'], 
                label=vehicle_id, alpha=0.7, linewidth=1)
    
    plt.xlabel('Time (s)', fontsize=12)
    plt.ylabel('Position Error (m)', fontsize=12)
    plt.title('Position Tracking Error Over Time', fontsize=14, fontweight='bold')
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left', fontsize=8)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    
    output_path = os.path.join(output_dir, 'position_error_vs_time.png')
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"\nSaved plot: {output_path}")
    plt.close()


def plot_error_distribution(df, output_dir):
    """Plot histogram of position errors"""
    fig, axes = plt.subplots(1, 3, figsize=(15, 4))
    
    # Position Error
    axes[0].hist(df['PositionError'], bins=50, alpha=0.7, color='blue', edgecolor='black')
    axes[0].set_xlabel('Position Error (m)', fontsize=11)
    axes[0].set_ylabel('Frequency', fontsize=11)
    axes[0].set_title('Position Error Distribution', fontweight='bold')
    axes[0].grid(True, alpha=0.3)
    axes[0].axvline(df['PositionError'].mean(), color='red', linestyle='--', 
                    label=f'Mean: {df["PositionError"].mean():.3f}m')
    axes[0].legend()
    
    # Lateral Error
    axes[1].hist(df['LateralError'], bins=50, alpha=0.7, color='green', edgecolor='black')
    axes[1].set_xlabel('Lateral Error (m)', fontsize=11)
    axes[1].set_ylabel('Frequency', fontsize=11)
    axes[1].set_title('Lateral Error Distribution', fontweight='bold')
    axes[1].grid(True, alpha=0.3)
    axes[1].axvline(0, color='red', linestyle='--', alpha=0.5)
    
    # Longitudinal Error
    axes[2].hist(df['LongitudinalError'], bins=50, alpha=0.7, color='orange', edgecolor='black')
    axes[2].set_xlabel('Longitudinal Error (m)', fontsize=11)
    axes[2].set_ylabel('Frequency', fontsize=11)
    axes[2].set_title('Longitudinal Error Distribution', fontweight='bold')
    axes[2].grid(True, alpha=0.3)
    axes[2].axvline(0, color='red', linestyle='--', alpha=0.5)
    
    plt.tight_layout()
    output_path = os.path.join(output_dir, 'error_distributions.png')
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Saved plot: {output_path}")
    plt.close()


def plot_2d_trajectory_comparison(df, output_dir, vehicle_id=None):
    """Plot 2D trajectory comparison between Unity and SUMO"""
    if vehicle_id:
        data = df[df['VehicleID'] == vehicle_id]
        title_suffix = f" - {vehicle_id}"
    else:
        # Use first vehicle if not specified
        vehicle_id = df['VehicleID'].iloc[0]
        data = df[df['VehicleID'] == vehicle_id]
        title_suffix = f" - {vehicle_id}"
    
    plt.figure(figsize=(12, 10))
    
    # Plot trajectories
    plt.plot(data['UnityX'], data['UnityZ'], 'b-', label='Unity (Simulated)', 
             linewidth=2, alpha=0.7)
    plt.plot(data['SumoX'], data['SumoZ'], 'r--', label='SUMO (Ground Truth)', 
             linewidth=2, alpha=0.7)
    
    # Mark start and end points
    plt.plot(data['UnityX'].iloc[0], data['UnityZ'].iloc[0], 'go', 
             markersize=10, label='Start')
    plt.plot(data['UnityX'].iloc[-1], data['UnityZ'].iloc[-1], 'ro', 
             markersize=10, label='End')
    
    plt.xlabel('X Position (m)', fontsize=12)
    plt.ylabel('Z Position (m)', fontsize=12)
    plt.title(f'2D Trajectory Comparison{title_suffix}', fontsize=14, fontweight='bold')
    plt.legend(fontsize=10)
    plt.grid(True, alpha=0.3)
    plt.axis('equal')
    plt.tight_layout()
    
    output_path = os.path.join(output_dir, f'trajectory_comparison_{vehicle_id}.png')
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Saved plot: {output_path}")
    plt.close()


def plot_lateral_vs_longitudinal(df, output_dir):
    """Plot lateral vs longitudinal error scatter"""
    plt.figure(figsize=(10, 10))
    
    plt.scatter(df['LateralError'], df['LongitudinalError'], 
                alpha=0.5, s=10, c=df['PositionError'], cmap='viridis')
    
    plt.xlabel('Lateral Error (m)', fontsize=12)
    plt.ylabel('Longitudinal Error (m)', fontsize=12)
    plt.title('Lateral vs Longitudinal Error', fontsize=14, fontweight='bold')
    plt.axhline(y=0, color='k', linestyle='--', alpha=0.3)
    plt.axvline(x=0, color='k', linestyle='--', alpha=0.3)
    plt.grid(True, alpha=0.3)
    plt.colorbar(label='Position Error (m)')
    plt.axis('equal')
    plt.tight_layout()
    
    output_path = os.path.join(output_dir, 'lateral_vs_longitudinal.png')
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Saved plot: {output_path}")
    plt.close()


def export_summary_report(df, output_dir):
    """Export a text summary report"""
    report_path = os.path.join(output_dir, 'analysis_report.txt')
    
    with open(report_path, 'w') as f:
        f.write("="*70 + "\n")
        f.write("POSITION ACCURACY ANALYSIS REPORT\n")
        f.write("="*70 + "\n\n")
        
        f.write(f"Analysis Date: {pd.Timestamp.now()}\n")
        f.write(f"Total Entries: {len(df)}\n")
        f.write(f"Number of Vehicles: {df['VehicleID'].nunique()}\n")
        f.write(f"Simulation Duration: {df['Timestamp'].max() - df['Timestamp'].min():.2f} seconds\n\n")
        
        f.write("="*70 + "\n")
        f.write("OVERALL STATISTICS\n")
        f.write("="*70 + "\n")
        f.write(df['PositionError'].describe().to_string())
        f.write("\n\n")
        
        f.write("="*70 + "\n")
        f.write("PER-VEHICLE STATISTICS\n")
        f.write("="*70 + "\n\n")
        
        for vehicle_id in sorted(df['VehicleID'].unique()):
            vehicle_data = df[df['VehicleID'] == vehicle_id]
            f.write(f"\n{vehicle_id}:\n")
            f.write(f"  Samples: {len(vehicle_data)}\n")
            f.write(f"  Position Error (mean): {vehicle_data['PositionError'].mean():.4f} m\n")
            f.write(f"  Position Error (max):  {vehicle_data['PositionError'].max():.4f} m\n")
            f.write(f"  Position Error (std):  {vehicle_data['PositionError'].std():.4f} m\n")
    
    print(f"\nSaved report: {report_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_position_accuracy.py <log_file.csv>")
        print("\nExample:")
        print("  python analyze_position_accuracy.py Logs/PositionAccuracy/position_accuracy_2025-11-04_12-30-00.csv")
        sys.exit(1)
    
    log_file = sys.argv[1]
    
    if not os.path.exists(log_file):
        print(f"Error: File not found: {log_file}")
        sys.exit(1)
    
    print(f"Loading log file: {log_file}")
    df = load_log_file(log_file)
    
    # Create output directory for plots
    output_dir = os.path.join(os.path.dirname(log_file), 'analysis')
    os.makedirs(output_dir, exist_ok=True)
    
    # Print statistics
    print_summary_statistics(df)
    print_per_vehicle_statistics(df)
    
    # Generate plots
    print("\n" + "="*70)
    print("GENERATING PLOTS")
    print("="*70)
    
    plot_position_error_over_time(df, output_dir)
    plot_error_distribution(df, output_dir)
    plot_2d_trajectory_comparison(df, output_dir)
    plot_lateral_vs_longitudinal(df, output_dir)
    
    # Export report
    export_summary_report(df, output_dir)
    
    print("\n" + "="*70)
    print("ANALYSIS COMPLETE")
    print("="*70)
    print(f"\nAll outputs saved to: {output_dir}")


if __name__ == "__main__":
    main()
