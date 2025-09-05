<script>
    import "../index.scss";
    import { onMount } from "svelte";
    import UrlApi from "$lib/urlApi.js";
    import { canisterId } from "$lib/canisters.js";

    let urls = [];
    let loading = false;
    let error = "";
    let successMessage = "";
    let newUrl = "";
    let customSlug = "";
    let copiedShortUrl = "";

    // Get the base URL for curl examples
    function getBaseUrl(raw = true) {
        let canisterIdAndRaw = raw ? `${canisterId}.raw` : canisterId;
        if (typeof window !== "undefined") {
            const isLocal =
                window.location.hostname === "localhost" ||
                window.location.hostname === "127.0.0.1";
            if (isLocal) {
                return `http://${canisterIdAndRaw}.localhost:4943`;
            } else {
                return `https://${canisterIdAndRaw}.ic0.app`;
            }
        }
        return `http://${canisterIdAndRaw}.localhost:4943`; // fallback for SSR
    }

    // Get the base URL for dynamic usage;

    // Generate dynamic curl command based on current input
    $: curlCommand = (() => {
        const baseUrl = getBaseUrl();

        if (!newUrl.trim()) {
            return `curl '${baseUrl}/shorten' \\
  -H 'Accept: */*' \\
  -H 'Content-Type: text/plain' \\
  -d 'https://example.com'`;
        }

        if (customSlug.trim()) {
            return `curl '${baseUrl}/shorten' \\
  -H 'Accept: */*' \\
  -H 'Content-Type: application/x-www-form-urlencoded' \\
  -d 'url=${encodeURIComponent(newUrl)}&slug=${encodeURIComponent(customSlug)}'`;
        } else {
            return `curl '${baseUrl}/shorten' \\
  -H 'Accept: */*' \\
  -H 'Content-Type: text/plain' \\
  -d '${newUrl}'`;
        }
    })();

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
            showSuccess(`[>] Short URL created: ${fullShortUrl}`);
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
            showSuccess(`Short URL deleted successfully`);
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
                showSuccess(`[C] Copied to clipboard: ${text}`);

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
        // Convert nanoseconds to milliseconds for JavaScript Date
        const milliseconds = Math.floor(timestamp / 1000000);
        return new Date(milliseconds).toLocaleString();
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
        <h1>Liminal URL Shortener</h1>
        <p>
            Shorten URLs with HTTP-native features using <a
                href="https://mops.one/liminal"
                target="_blank">Liminal HTTP framework</a
            > for Motoko
        </p>
    </div>

    {#if error}
        <div class="error-message">
            <span>[!] {error}</span>
            <button class="close-error" on:click={clearError} type="button"
                >×</button
            >
        </div>
    {/if}

    {#if successMessage}
        <div class="success-message">
            <span>[OK] {successMessage}</span>
            <button class="close-success" on:click={clearSuccess} type="button"
                >×</button
            >
        </div>
    {/if}

    <!-- Shorten URL Form -->
    <div class="shorten-section">
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

            <!-- Action buttons side by side -->
            <div class="action-row">
                <button
                    type="submit"
                    disabled={loading || !newUrl.trim() || !isValidUrl(newUrl)}
                    class="shorten-btn"
                >
                    {loading ? "Shortening..." : "[>] Shorten URL"}
                </button>

                <div
                    class="curl-alternative"
                    class:disabled={!newUrl.trim() || !isValidUrl(newUrl)}
                >
                    <p class="curl-label">Or use curl:</p>
                    <div class="curl-command-container">
                        <code class="curl-command dynamic">{curlCommand}</code>
                        <button
                            type="button"
                            class="copy-btn"
                            disabled={!newUrl.trim() || !isValidUrl(newUrl)}
                            on:click={() => copyToClipboard(curlCommand)}
                        >
                            [COPY] Copy curl
                        </button>
                    </div>
                </div>
            </div>
        </form>
    </div>

    <!-- URLs List -->
    <div class="urls-section">
        <div class="section-header">
            <h2>Your Short URLs ({urls.length})</h2>
            <button on:click={loadUrls} disabled={loading} class="refresh-btn">
                {loading ? "[...] Loading..." : "Refresh"}
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
                                            ? "Copied ✓"
                                            : "Copy Url"}
                                    </button>
                                    <button
                                        class="visit-btn"
                                        on:click={() =>
                                            openUrl(
                                                UrlApi.getShortUrl(
                                                    url.shortCode
                                                )
                                            )}
                                    >
                                        ↗
                                    </button>
                                    <button
                                        on:click={() => deleteUrl(url.id)}
                                        disabled={loading}
                                        class="delete-btn"
                                    >
                                        X
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
                                        >[HITS] {url.clicks || 0} clicks</span
                                    >
                                    <span class="stat"
                                        >[DATE] {formatDate(
                                            url.createdAt
                                        )}</span
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
