import csv
import matplotlib.pyplot as plt



def open_csv(file_path):
    """Open a CSV file and return its contents as a list of dictionaries."""
    with open(file_path, mode='r') as csvfile:
        reader = csv.DictReader(csvfile)
        data = [row for row in reader]
    return data

def plot_graph(x_data, y_data, x_label, y_label, title, output_file):
    """Plot a graph and save it to a file."""
    # Set style and create figure with better size
    plt.style.use('seaborn-v0_8-darkgrid')
    fig, ax = plt.subplots(figsize=(10, 6), dpi=100)
    #add another plot for second y axis
    ax2 = ax.twinx()

        
    # Plot with improved styling
    ax.plot(x_data, y_data, 
            marker='o', 
            markersize=8,
            linewidth=2, 
            color='#2E86AB',
            markerfacecolor='#A23B72',
            markeredgecolor='white',
            markeredgewidth=1.5,
            alpha=0.8,
            label='Transfer Rate')

    
    
    # Enhance labels and title
    ax.set_xlabel(x_label, fontsize=12, fontweight='bold')
    ax.set_ylabel(y_label, fontsize=12, fontweight='bold')
    ax.set_title(title, fontsize=14, fontweight='bold', pad=20)
    #plt.xticks(rotation=45, ha='right')
    
    # Improve grid
    ax.grid(True, alpha=0.3, linestyle='--', linewidth=0.8)
    ax.tick_params(axis='both', which='both', labelsize=10)

    
    # Add legend
    #ax.legend(loc='best', frameon=True, shadow=True)
    
    # Tight layout to prevent label cutoff
    plt.tight_layout()
    #fig.autofmt_xdate()
    # Save with high quality
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()




if __name__ == "__main__":
    csv_file_path = 'MultiHopTest.csv'
    data = open_csv(csv_file_path)


    x_data = [(row['Distance to Sender (Haversin) ']) for row in data if row['Latitude'] and row['Latitude'] != '0']
    y_data = [float(row['Transfer']) for row in data if row['Latitude'] and row['Latitude'] != '0']
    
    x2_data = [(row['HopCount']) for row in data]
    #y_data = [(row['Timestamp']) for row in data]

    plot_graph(
        x_data,
        y_data,

        x_label='Distance (m)',
        y_label='Transfer (Mbps)',
        title='Transfer vs Distance',
        output_file='test.png'
    )