# 👻 Motoko Ghost Manager

A beautiful CRUD (Create, Read, Update, Delete) demo application for managing Motoko Ghosts on the Internet Computer. This demo showcases how to build a modern web interface that interacts with a Motoko backend using the Liminal HTTP framework.

## Features

- 🎨 **Beautiful UI**: Modern, responsive design with smooth animations
- 👻 **Ghost Management**: Create, view, edit, and delete ghosts
- 🔄 **Real-time Updates**: Live data synchronization with the backend
- ⚡ **Fast & Responsive**: Built with SvelteKit for optimal performance
- 🎯 **Type-safe API**: Structured API client for reliable data handling
- ♿ **Accessible**: Keyboard shortcuts and screen reader friendly
- 📱 **Mobile Friendly**: Responsive design that works on all devices

## Backend API

The backend provides a RESTful API for ghost management:

- `GET /ghosts` - Get all ghosts
- `POST /ghosts` - Create a new ghost
- `GET /ghosts/{id}` - Get a specific ghost
- `POST /ghosts/{id}` - Update a ghost
- `DELETE /ghosts/{id}` - Delete a ghost

### Ghost Data Structure

```motoko
type Ghost = {
    id: Nat;
    name: Text;
};
```

## Frontend Architecture

### Components

- **+page.svelte**: Main application component with full CRUD interface
- **ghostApi.js**: API client for backend communication
- **index.scss**: Modern styling with CSS Grid and Flexbox

### Key Features

- **State Management**: Reactive Svelte stores for real-time UI updates
- **Error Handling**: User-friendly error messages with retry functionality
- **Loading States**: Visual feedback during API operations
- **Form Validation**: Client-side validation with server-side backup
- **Success Feedback**: Confirmation messages for successful operations

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

### Adding a Ghost

1. Enter a name in the "Add New Ghost" section
2. Click "👻 Add Ghost" or press Enter
3. The ghost will appear in your collection

### Editing a Ghost

1. Click "✏️ Edit" on any ghost card
2. Modify the name in the input field
3. Click "💾 Save" or press Enter to confirm
4. Click "❌ Cancel" or press Escape to cancel

### Deleting a Ghost

1. Click "🗑️ Delete" on any ghost card
2. Confirm the deletion in the popup dialog
3. The ghost will be removed from your collection

### Keyboard Shortcuts

- **Escape**: Cancel editing mode
- **Ctrl/Cmd + R**: Refresh ghost list
- **Enter**: Submit forms (add/edit)

## Technical Details

### API Client (`ghostApi.js`)

- Promise-based HTTP client
- Automatic error handling and validation
- Type-safe request/response handling
- Consistent error messaging

### Styling (`index.scss`)

- CSS Grid for responsive layouts
- Smooth transitions and animations
- Modern color scheme with gradients
- Mobile-first responsive design
- Accessibility-focused styles

### State Management

- Reactive variables for UI state
- Optimistic updates for better UX
- Error state management
- Loading state coordination

## Error Handling

The application includes comprehensive error handling:

- **Network errors**: Connection issues with the backend
- **Validation errors**: Invalid input data
- **Not found errors**: Attempting to access non-existent ghosts
- **Server errors**: Backend processing issues

All errors are displayed to users with clear, actionable messages.

## Performance Optimizations

- **Efficient updates**: Only re-render changed components
- **Optimistic UI**: Immediate feedback for user actions
- **Minimal API calls**: Batch operations where possible
- **Cached data**: Reduce redundant requests

## Browser Support

- Modern browsers with ES6+ support
- Chrome 60+
- Firefox 60+
- Safari 12+
- Edge 79+

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is part of the Liminal framework examples and follows the same license terms.
