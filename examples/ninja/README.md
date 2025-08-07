# Liminal URL Shortener

A retro terminal-styled URL shortener demo showcasing HTTP-native features on the Internet Computer. This demo demonstrates how to build a functional web service using the Liminal HTTP framework with Motoko, emphasizing curl usage and proper HTTP semantics.

## Features

-   🖥️ **Retro Terminal UI**: Old-school green-on-black terminal aesthetic
-   � **URL Shortening**: Create short, memorable links from long URLs
-   🎯 **Custom Short Codes**: Optional custom slugs for branded links
-   📊 **Click Tracking**: Monitor usage statistics for your links
-   � **HTTP-Native**: Full REST API with proper status codes and redirects
-   📋 **Dynamic curl Examples**: Live curl commands that update with your input
-   ⚡ **Real-time Updates**: Instant feedback and live data synchronization
-   📱 **Responsive Design**: Terminal theme that works on all devices

## Backend API

The backend provides a RESTful HTTP API for URL shortening:

-   `POST /shorten` - Create a short URL (accepts form data or plain text)
-   `GET /s/{shortCode}` - Redirect to original URL (HTTP 302)
-   `GET /urls` - Get all short URLs with metadata
-   `DELETE /urls/{id}` - Delete a short URL
-   `GET /s/{shortCode}/stats` - Get click statistics (optional)

### URL Data Structure

```motoko
type ShortenedUrl = {
    id: Nat;
    shortCode: Text;
    originalUrl: Text;
    clicks: Nat;
    createdAt: Int;
};
```

### HTTP Content Types

The API supports multiple content types for creating short URLs:

```bash
# Plain text body
curl -X POST -d "https://example.com" http://canister.localhost:4943/shorten

# Form data with custom slug
curl -X POST -d "url=https://example.com&slug=my-link" http://canister.localhost:4943/shorten

# Returns JSON response
{"id":1,"shortCode":"abc123","originalUrl":"https://example.com","clicks":0,"createdAt":1625097600000000000}
```

## Frontend Architecture

### Components

-   **+page.svelte**: Main URL shortener interface with dynamic curl examples
-   **urlApi.js**: HTTP client for backend communication
-   **index.scss**: Retro terminal styling with green-on-black theme

### Key Features

-   **Dynamic curl Commands**: Interactive curl examples that update based on user input
-   **Terminal Aesthetics**: Monospace fonts, green text, and square brackets for buttons
-   **HTTP Awareness**: Emphasizes the HTTP nature of the service with curl integration
-   **Form Validation**: URL validation with user-friendly error messages
-   **Copy to Clipboard**: Easy copying of short URLs and curl commands

## Getting Started

1. **Start the backend**:

    ```bash
    cd examples/ninja
    dfx start --background
    dfx deploy
    ```

2. **Start the frontend**:

    ```bash
    cd src/frontend
    npm install
    npm run start
    ```

3. **Open your browser** and navigate to `http://localhost:3000`

## Usage

### Creating Short URLs

#### Via Web Interface

1. Enter a long URL in the "Long URL" field
2. Optionally add a custom short code (letters, numbers, hyphens, underscores)
3. Click "[>] Shorten URL"
4. Copy the generated short URL or use the provided curl command

#### Via curl (HTTP API)

```bash
# Simple URL shortening
curl -X POST -d "https://example.com/very/long/url" http://canister.localhost:4943/shorten

# Custom short code
curl -X POST -d "url=https://example.com&slug=my-link" http://canister.localhost:4943/shorten

# Using the short URL (redirects with HTTP 302)
curl -L http://canister.localhost:4943/s/abc123
```

### Managing Short URLs

-   **Copy**: Click "[C]" to copy the short URL to clipboard
-   **Visit**: Click "↗" to open the short URL in a new tab
-   **Delete**: Click "[X]" to permanently remove the short URL
-   **Stats**: View click counts and creation dates for each URL

### Keyboard Shortcuts

-   **Escape**: Clear the form inputs
-   **Ctrl/Cmd + R**: Refresh URL list
-   **Enter**: Submit the shorten form

## Technical Details

### HTTP Features Demonstrated

-   **Content Negotiation**: Supports both `text/plain` and `application/x-www-form-urlencoded`
-   **HTTP Redirects**: Proper 302 redirects for short URL visits
-   **Status Codes**: Appropriate HTTP status codes for all operations
-   **REST API**: Full RESTful interface following HTTP conventions

### API Client (`urlApi.js`)

-   HTTP-focused client emphasizing proper headers and content types
-   Environment-aware URL construction (local vs IC deployment)
-   Form data and plain text request handling
-   JSON response parsing with error handling

### Styling (`index.scss`)

-   **Terminal Theme**: Green-on-black color scheme with monospace fonts
-   **Retro Aesthetics**: Square buttons with bracket notation `[COPY]`, `[>]`
-   **Responsive Design**: Mobile-friendly layout that maintains terminal feel
-   **HTTP Emphasis**: Styling that reinforces the web service nature

### State Management

-   **Reactive curl Commands**: Dynamic generation of curl examples
-   **Real-time Validation**: Live URL validation and button state management
-   **Optimistic Updates**: Immediate UI feedback for better UX

## HTTP API Examples

### Creating Short URLs

```bash
# Basic shortening
$ curl -X POST -d "https://github.com/dfinity/motoko" \
  http://canister.localhost:4943/shorten

{"id":1,"shortCode":"abc123","originalUrl":"https://github.com/dfinity/motoko","clicks":0,"createdAt":1625097600000000000}

# Custom short code
$ curl -X POST -d "url=https://internetcomputer.org&slug=ic" \
  http://canister.localhost:4943/shorten

{"id":2,"shortCode":"ic","originalUrl":"https://internetcomputer.org","clicks":0,"createdAt":1625097600000000000}
```

### Using Short URLs

```bash
# Get redirect (follows automatically with -L)
$ curl -L http://canister.localhost:4943/s/abc123
# Redirects to https://github.com/dfinity/motoko

# See redirect response
$ curl -i http://canister.localhost:4943/s/abc123
HTTP/1.1 302 Found
Location: https://github.com/dfinity/motoko
```

### Managing URLs

```bash
# List all URLs
$ curl http://canister.localhost:4943/urls

# Delete a URL
$ curl -X DELETE http://canister.localhost:4943/urls/1
```

## Error Handling

The application includes comprehensive error handling:

-   **Invalid URLs**: Client-side validation with helpful error messages
-   **Duplicate slugs**: Server-side validation for custom short codes
-   **Not found errors**: Proper 404 responses for missing short URLs
-   **Network errors**: Connection issues with clear user feedback

All errors maintain the terminal aesthetic with `[!]` prefixes and monospace styling.

## Browser Support

-   Modern browsers with ES6+ support and fetch API
-   Chrome 60+
-   Firefox 60+
-   Safari 12+
-   Edge 79+

## Deployment

### Local Development

The demo runs locally using dfx with raw domain access:

```bash
# Backend available at:
http://{canister-id}.raw.localhost:4943

# Frontend available at:
http://localhost:3000
```

### IC Mainnet

For production deployment:

```bash
# Backend available at:
https://{canister-id}.ic0.app

# Redirects work at:
https://{canister-id}.ic0.app/s/{shortCode}
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test with both curl and web interface
4. Ensure terminal styling is maintained
5. Submit a pull request

## License

This project is part of the Liminal framework examples and follows the same license terms.
