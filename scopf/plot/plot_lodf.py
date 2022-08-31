import numpy as np
import matplotlib.pyplot as plt


def plot_save_matrix_heatmap(matrix, title: str, plot_file_name: str):
    abs_matrix = np.absolute(matrix)
    fig = plt.figure(figsize=(8, 6))
    plt.imshow(abs_matrix, cmap="Oranges")
    plt.title(title)
    plt.savefig(f"{plot_file_name}.svg")


if __name__ == "__main__":
    ptdf_matrix = np.load("../optimizer/ptdf.npy", allow_pickle=True)
    plot_save_matrix_heatmap(ptdf_matrix, "PTDF", "ptdf")
