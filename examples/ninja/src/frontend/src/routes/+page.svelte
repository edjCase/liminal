<script>
    import "../index.scss";
    import { onMount } from "svelte";
    import UrlApi from "$lib/urlApi.js";

    let urls = [];
    let loading = false;
    let error = "";
    let successMessage = "";
    let newUrl = "";
    let customSlug = "";
    let copiedShortUrl = "";

    async function loadUrls() {
        loading = true;
        error = "";
        try {
            urls = await UrlApi.getAllUrls();
        } catch (err) {
            error = "Failed to load URLs: " + err.message;
            console.error("Error loading URLs:", err);
        } finally {
            loading = false;
        }
    }

    async function shortenUrl() {
        if (!newUrl.trim()) {
            error = "Please enter a URL to shorten";
            return;
        }

        // Basic URL validation
        try {
            new URL(newUrl);
        } catch {
            error = "Please enter a valid URL (including http:// or https://)";
            return;
        }

        loading = true;
        error = "";
        try {
            const shortenedUrl = await UrlApi.createShortUrl(
                newUrl,
                customSlug || null
            );
            urls = [shortenedUrl, ...urls]; // Add to beginning of list
            newUrl = "";
            customSlug = "";

            // Show success message
            const shortCode = shortenedUrl.shortCode;
            const fullShortUrl = UrlApi.getShortUrl(shortCode);
            showSuccess(`🔗 Short URL created: ${fullShortUrl}`);
        } catch (err) {
            error = "Failed to shorten URL: " + err.message;
            console.error("Error shortening URL:", err);
        } finally {
            loading = false;
        }
    }

    async function deleteUrl(id) {
        const urlItem = urls.find((u) => u.id === id);
        if (
            !confirm(
                `Are you sure you want to delete the short URL "${urlItem?.shortCode || "this URL"}"?`
            )
        )
            return;

        loading = true;
        error = "";
        try {
            await UrlApi.deleteUrl(id);
            urls = urls.filter((url) => url.id !== id);
            showSuccess(`�️ Short URL deleted successfully`);
        } catch (err) {
            error = "Failed to delete URL: " + err.message;
            console.error("Error deleting URL:", err);
        } finally {
            loading = false;
        }
    }

    function copyToClipboard(text) {
        navigator.clipboard
            .writeText(text)
            .then(() => {
                copiedShortUrl = text;
                showSuccess(`📋 Copied to clipboard: ${text}`);

                // Clear the copied state after 2 seconds
                setTimeout(() => {
                    copiedShortUrl = "";
                }, 2000);
            })
            .catch(() => {
                error = "Failed to copy to clipboard";
            });
    }

    function openUrl(url) {
        window.open(url, "_blank");
    }

    function handleKeydown(event) {
        // ESC key to clear form
        if (event.key === "Escape") {
            newUrl = "";
            customSlug = "";
            clearError();
        }
        // Ctrl+R or Cmd+R to refresh
        if ((event.ctrlKey || event.metaKey) && event.key === "r") {
            event.preventDefault();
            loadUrls();
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

    function formatDate(timestamp) {
        return new Date(timestamp).toLocaleString();
    }

    function isValidUrl(string) {
        try {
            new URL(string);
            return true;
        } catch {
            return false;
        }
    }

    onMount(() => {
        loadUrls();
        document.addEventListener("keydown", handleKeydown);

        return () => {
            document.removeEventListener("keydown", handleKeydown);
        };
    });
</script>

<main>
    <div class="header">
        <img src="/logo2.svg" alt="DFINITY logo" />
        <h1>� Liminal URL Shortener</h1>
        <p>
            Shorten URLs with HTTP-native features. Perfect for curl and browser
            usage!
        </p>
    </div>

    {#if error}
        <div class="error-message">
            <span>⚠️ {error}</span>
            <button class="close-error" on:click={clearError} type="button"
                >×</button
            >
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

    <!-- Shorten URL Form -->
    <div class="shorten-section">
        <h2>Shorten a URL</h2>
        <form on:submit|preventDefault={shortenUrl} class="shorten-form">
            <div class="form-field">
                <label for="new-url" class="form-label">Long URL</label>
                <input
                    id="new-url"
                    type="url"
                    bind:value={newUrl}
                    placeholder="https://example.com/very/long/url..."
                    disabled={loading}
                    required
                    class="form-input url-input"
                />
            </div>

            <div class="form-field">
                <label for="custom-slug" class="form-label"
                    >Custom Short Code (Optional)</label
                >
                <input
                    id="custom-slug"
                    type="text"
                    bind:value={customSlug}
                    placeholder="my-link"
                    disabled={loading}
                    pattern="[a-zA-Z0-9-_]+"
                    maxlength="20"
                    class="form-input"
                />
                <small class="form-help"
                    >Letters, numbers, hyphens, and underscores only</small
                >
            </div>

            <button
                type="submit"
                disabled={loading || !newUrl.trim() || !isValidUrl(newUrl)}
                class="shorten-btn"
            >
                {loading ? "Shortening..." : "🔗 Shorten URL"}
            </button>
        </form>
    </div>

    <!-- Curl Examples -->
    <div class="curl-section">
        <h2>📋 Try with curl</h2>
        <div class="curl-examples">
            <div class="curl-example">
                <h3>Create a short URL</h3>
                <code class="curl-command"
                    >curl -X POST -d "https://example.com"
                    http://localhost:8000/shorten</code
                >
                <button
                    class="copy-btn"
                    on:click={() =>
                        copyToClipboard(
                            'curl -X POST -d "https://example.com" http://localhost:8000/shorten'
                        )}
                >
                    📋 Copy
                </button>
            </div>

            <div class="curl-example">
                <h3>Create with custom slug</h3>
                <code class="curl-command"
                    >curl -X POST -d "url=https://example.com&slug=my-link"
                    http://localhost:8000/shorten</code
                >
                <button
                    class="copy-btn"
                    on:click={() =>
                        copyToClipboard(
                            'curl -X POST -d "url=https://example.com&slug=my-link" http://localhost:8000/shorten'
                        )}
                >
                    📋 Copy
                </button>
            </div>

            <div class="curl-example">
                <h3>Follow a redirect</h3>
                <code class="curl-command"
                    >curl -L http://localhost:8000/s/abc123</code
                >
                <button
                    class="copy-btn"
                    on:click={() =>
                        copyToClipboard(
                            "curl -L http://localhost:8000/s/abc123"
                        )}
                >
                    📋 Copy
                </button>
            </div>

            <div class="curl-example">
                <h3>Get redirect info (no follow)</h3>
                <code class="curl-command"
                    >curl -I http://localhost:8000/s/abc123</code
                >
                <button
                    class="copy-btn"
                    on:click={() =>
                        copyToClipboard(
                            "curl -I http://localhost:8000/s/abc123"
                        )}
                >
                    📋 Copy
                </button>
            </div>
        </div>
    </div>

    <!-- URLs List -->
    <div class="urls-section">
        <div class="section-header">
            <h2>Your Short URLs ({urls.length})</h2>
            <button on:click={loadUrls} disabled={loading} class="refresh-btn">
                {loading ? "🔄 Loading..." : "🔄 Refresh"}
            </button>
        </div>

        {#if loading && urls.length === 0}
            <div class="loading">Loading URLs...</div>
        {:else if urls.length === 0}
            <div class="empty-state">
                <div class="empty-icon">�</div>
                <p>No short URLs yet. Create your first one above!</p>
            </div>
        {:else}
            <div class="urls-grid">
                {#each urls as url (url.id)}
                    <div class="url-card">
                        <div class="url-info">
                            <div class="url-header">
                                <h3 class="short-code">/{url.shortCode}</h3>
                                <div class="url-actions">
                                    <button
                                        class="copy-btn small"
                                        class:copied={copiedShortUrl ===
                                            UrlApi.getShortUrl(url.shortCode)}
                                        on:click={() =>
                                            copyToClipboard(
                                                UrlApi.getShortUrl(
                                                    url.shortCode
                                                )
                                            )}
                                    >
                                        {copiedShortUrl ===
                                        UrlApi.getShortUrl(url.shortCode)
                                            ? "✓"
                                            : "📋"}
                                    </button>
                                    <button
                                        class="visit-btn"
                                        on:click={() =>
                                            openUrl(url.originalUrl)}
                                    >
                                        🔗 Visit
                                    </button>
                                    <button
                                        on:click={() => deleteUrl(url.id)}
                                        disabled={loading}
                                        class="delete-btn"
                                    >
                                        🗑️
                                    </button>
                                </div>
                            </div>

                            <div class="url-details">
                                <p class="short-url">
                                    <strong>Short:</strong>
                                    <a
                                        href={UrlApi.getShortUrl(url.shortCode)}
                                        target="_blank"
                                        rel="noopener"
                                    >
                                        {UrlApi.getShortUrl(url.shortCode)}
                                    </a>
                                </p>
                                <p class="original-url">
                                    <strong>Original:</strong>
                                    <a
                                        href={url.originalUrl}
                                        target="_blank"
                                        rel="noopener"
                                        class="original-link"
                                    >
                                        {url.originalUrl}
                                    </a>
                                </p>
                                <div class="url-stats">
                                    <span class="stat"
                                        >👀 {url.clicks || 0} clicks</span
                                    >
                                    <span class="stat"
                                        >� {formatDate(url.createdAt)}</span
                                    >
                                </div>
                            </div>
                        </div>
                    </div>
                {/each}
            </div>
        {/if}
    </div>
</main>
