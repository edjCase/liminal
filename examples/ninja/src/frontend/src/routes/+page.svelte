<script>
  import "../index.scss";
  import { onMount } from "svelte";
  import GhostApi from "$lib/ghostApi.js";

  let ghosts = [];
  let loading = false;
  let error = "";
  let successMessage = "";
  let editingGhost = null;
  let newGhostName = "";
  let newGhostImage = null;
  let editGhostName = "";
  let editGhostImage = null;
  let updatedGhostIds = new Set(); // Track which ghosts had their images updated

  async function loadGhosts() {
    loading = true;
    error = "";
    try {
      ghosts = await GhostApi.getAllGhosts();
    } catch (err) {
      error = "Failed to load ghosts: " + err.message;
      console.error("Error loading ghosts:", err);
    } finally {
      loading = false;
    }
  }

  async function createGhost() {
    if (!newGhostName.trim()) return;
    if (!newGhostImage) {
      error = "Please select an image for your ghost";
      return;
    }

    loading = true;
    error = "";
    try {
      const newGhost = await GhostApi.createGhost(newGhostName, newGhostImage);
      ghosts = [...ghosts, newGhost];
      newGhostName = "";
      newGhostImage = null;

      // Reset file input
      const fileInput = document.querySelector("#new-ghost-image");
      if (fileInput) fileInput.value = "";

      // Show success message briefly
      const successMsg = `👻 "${newGhost.name}" has been added to your collection!`;
      showSuccess(successMsg);
    } catch (err) {
      error = "Failed to create ghost: " + err.message;
      console.error("Error creating ghost:", err);
    } finally {
      loading = false;
    }
  }

  async function updateGhost(id) {
    if (!editGhostName.trim()) return;

    loading = true;
    error = "";
    try {
      const hadImageUpdate = editGhostImage !== null;
      
      await GhostApi.updateGhost(id, editGhostName, editGhostImage);
      
      // If image was updated, mark this ghost for cache-busting
      if (hadImageUpdate) {
        updatedGhostIds.add(id);
        updatedGhostIds = updatedGhostIds; // Trigger reactivity
      }
      
      // Reload the entire ghost list to get updated data (including new images)
      await loadGhosts();
      
      editingGhost = null;
      editGhostName = "";
      editGhostImage = null;

      // Show success message briefly
      showSuccess(`👻 Ghost updated successfully!`);
    } catch (err) {
      error = "Failed to update ghost: " + err.message;
      console.error("Error updating ghost:", err);
    } finally {
      loading = false;
    }
  }

  async function deleteGhost(id) {
    const ghost = ghosts.find((g) => g.id === id);
    if (
      !confirm(
        `Are you sure you want to delete "${ghost?.name || "this ghost"}"?`
      )
    )
      return;

    loading = true;
    error = "";
    try {
      await GhostApi.deleteGhost(id);
      ghosts = ghosts.filter((ghost) => ghost.id !== id);

      // Show success message briefly
      showSuccess(
        `👻 "${ghost?.name || "Ghost"}" has been removed from your collection.`
      );
    } catch (err) {
      error = "Failed to delete ghost: " + err.message;
      console.error("Error deleting ghost:", err);
    } finally {
      loading = false;
    }
  }

  function startEdit(ghost) {
    editingGhost = ghost.id;
    editGhostName = ghost.name;
    editGhostImage = null;
  }

  function cancelEdit() {
    editingGhost = null;
    editGhostName = "";
    editGhostImage = null;
  }

  function handleKeydown(event) {
    // ESC key to cancel editing
    if (event.key === "Escape" && editingGhost) {
      cancelEdit();
    }
    // Ctrl+R or Cmd+R to refresh (prevent default and use our refresh)
    if ((event.ctrlKey || event.metaKey) && event.key === "r") {
      event.preventDefault();
      loadGhosts();
    }
  }

  function clearError() {
    error = "";
  }

  function showSuccess(message) {
    successMessage = message;
    setTimeout(() => {
      successMessage = "";
    }, 3000);
  }

  function clearSuccess() {
    successMessage = "";
  }

  function handleImageUpload(event, isEdit = false) {
    const file = event.target.files[0];
    if (!file) return;

    // Validate file size (2MB)
    if (file.size > 2 * 1024 * 1024) {
      error = "Image must be under 2MB";
      event.target.value = "";
      return;
    }

    // Validate file type
    if (!file.type.startsWith("image/")) {
      error = "Please select an image file";
      event.target.value = "";
      return;
    }

    if (isEdit) {
      editGhostImage = file;
    } else {
      newGhostImage = file;
    }
  }

  function getImagePreviewUrl(file) {
    if (!file) return null;
    return URL.createObjectURL(file);
  }

  async function downloadSampleImage() {
    const imageUrl =
      "https://cdn-assets-eu.frontify.com/s3/frontify-enterprise-files-eu/eyJwYXRoIjoiZGZpbml0eVwvYWNjb3VudHNcLzAxXC80MDAwMzA0XC9wcm9qZWN0c1wvNFwvYXNzZXRzXC8zOFwvMTc2XC9jZGYwZTJlOTEyNDFlYzAzZTQ1YTVhZTc4OGQ0ZDk0MS0xNjA1MjIyMzU4LnBuZyJ9:dfinity:9Q2_9PEsbPqdJNAQ08DAwqOenwIo7A8_tCN4PSSWkAM?width=2400";

    try {
      // Show loading state
      const originalText = document.querySelector(".sample-link").textContent;
      document.querySelector(".sample-link").textContent = "⏳ Downloading...";

      const response = await fetch(imageUrl);
      if (!response.ok) throw new Error("Failed to fetch image");

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);

      const a = document.createElement("a");
      a.style.display = "none";
      a.href = url;
      a.download = "sample-ghost.png";

      document.body.appendChild(a);
      a.click();

      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);

      // Reset button text
      document.querySelector(".sample-link").textContent = originalText;

      showSuccess("Sample ghost image downloaded successfully!");
    } catch (err) {
      error =
        'Failed to download sample image. You can try right-clicking and "Save As..." instead.';
      console.error("Download error:", err);

      // Reset button text
      document.querySelector(".sample-link").textContent =
        "📥 Download Sample Ghost Image";
    }
  }

  onMount(() => {
    loadGhosts();
    document.addEventListener("keydown", handleKeydown);

    return () => {
      document.removeEventListener("keydown", handleKeydown);
    };
  });
</script>

<main>
  <div class="header">
    <img src="/logo2.svg" alt="DFINITY logo" />
    <h1>👻 Motoko Ghost Manager</h1>
    <p>Manage your collection of Motoko Ghosts from the Internet Computer!</p>
  </div>

  {#if error}
    <div class="error-message">
      <span>⚠️ {error}</span>
      <button class="close-error" on:click={clearError} type="button">×</button>
    </div>
  {/if}

  {#if successMessage}
    <div class="success-message">
      <span>✅ {successMessage}</span>
      <button class="close-success" on:click={clearSuccess} type="button"
        >×</button
      >
    </div>
  {/if}

  <!-- Add New Ghost Form -->
  <div class="add-ghost-section">
    <h2>Add New Ghost</h2>
    <form on:submit|preventDefault={createGhost} class="add-ghost-form">
      <div class="form-field">
        <label for="new-ghost-name" class="form-label">Name</label>
        <input
          id="new-ghost-name"
          type="text"
          bind:value={newGhostName}
          placeholder="Enter ghost name..."
          disabled={loading}
          required
          maxlength="50"
          autocomplete="off"
          class="form-input"
        />
      </div>

      <div class="form-field">
        <label for="new-ghost-image" class="form-label">Image</label>
        <div class="image-upload-section">
          <div class="image-preview-container">
            {#if newGhostImage}
              <img
                src={getImagePreviewUrl(newGhostImage)}
                alt="Ghost preview"
                class="ghost-preview"
              />
            {:else}
              <div class="ghost-placeholder">
                <span class="placeholder-icon">👻</span>
                <span class="placeholder-text">No image selected</span>
              </div>
            {/if}
          </div>
        </div>
        {#if newGhostImage}
          <p class="preview-info">
            {newGhostImage.name} ({(newGhostImage.size / 1024).toFixed(1)} KB)
          </p>
        {/if}
        <div class="file-input-container">
          <label for="new-ghost-image" class="file-input-label">
            Choose Image
          </label>
          <input
            id="new-ghost-image"
            type="file"
            accept="image/*"
            on:change={(e) => handleImageUpload(e, false)}
            disabled={loading}
            required
            class="file-input"
          />
        </div>
        <div class="sample-ghost-link">
          <p>
            Need an image?
            <button
              on:click={downloadSampleImage}
              type="button"
              class="sample-link"
              disabled={loading}
            >
              📥 Download Sample Ghost Image
            </button>
          </p>
        </div>
      </div>

      <button
        type="submit"
        disabled={loading || !newGhostName.trim() || !newGhostImage}
        class="add-ghost-btn"
      >
        {loading ? "Adding..." : "👻 Add Ghost"}
      </button>
    </form>
  </div>

  <!-- Ghosts List -->
  <div class="ghosts-section">
    <div class="section-header">
      <h2>Your Ghosts ({ghosts.length})</h2>
      <button on:click={loadGhosts} disabled={loading} class="refresh-btn">
        {loading ? "🔄 Loading..." : "🔄 Refresh"}
      </button>
    </div>

    {#if loading && ghosts.length === 0}
      <div class="loading">Loading ghosts...</div>
    {:else if ghosts.length === 0}
      <div class="empty-state">
        <div class="empty-icon">👻</div>
        <p>No ghosts found. Add your first ghost above!</p>
      </div>
    {:else}
      <div class="ghosts-grid">
        {#each ghosts as ghost (ghost.id)}
          <div class="ghost-card">
            <div class="ghost-avatar">
              <img
                src={GhostApi.getImageUrl(ghost.id, updatedGhostIds.has(ghost.id))}
                alt={ghost.name}
                class="ghost-image"
                on:error={(e) => {
                  e.target.src = "/ghost-placeholder.svg";
                }}
              />
            </div>

            {#if editingGhost === ghost.id}
              <form
                on:submit|preventDefault={() => updateGhost(ghost.id)}
                class="edit-form"
              >
                <input
                  type="text"
                  bind:value={editGhostName}
                  disabled={loading}
                  required
                  maxlength="50"
                  autocomplete="off"
                />
                <div class="file-input-container">
                  <label
                    for="edit-ghost-image-{ghost.id}"
                    class="file-input-label small"
                  >
                    Change Image (Optional)
                  </label>
                  <input
                    id="edit-ghost-image-{ghost.id}"
                    type="file"
                    accept="image/*"
                    on:change={(e) => handleImageUpload(e, true)}
                    disabled={loading}
                    class="file-input"
                  />
                </div>
                {#if editGhostImage}
                  <div class="edit-preview">
                    <img
                      src={getImagePreviewUrl(editGhostImage)}
                      alt="Ghost preview"
                      class="ghost-preview small"
                    />
                    <p class="preview-info small">
                      {editGhostImage.name} ({(
                        editGhostImage.size / 1024
                      ).toFixed(1)} KB)
                    </p>
                  </div>
                {/if}
                <div class="edit-actions">
                  <button
                    type="submit"
                    disabled={loading || !editGhostName.trim()}
                  >
                    💾 Save
                  </button>
                  <button
                    type="button"
                    on:click={cancelEdit}
                    disabled={loading}
                  >
                    ❌ Cancel
                  </button>
                </div>
              </form>
            {:else}
              <div class="ghost-info">
                <h3 class="ghost-name">{ghost.name}</h3>
                <p class="ghost-id">ID: {ghost.id}</p>

                <div class="ghost-actions">
                  <button on:click={() => startEdit(ghost)} disabled={loading}>
                    ✏️ Edit
                  </button>
                  <button
                    on:click={() => deleteGhost(ghost.id)}
                    disabled={loading}
                    class="delete-btn"
                  >
                    🗑️ Delete
                  </button>
                </div>
              </div>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  </div>
</main>
