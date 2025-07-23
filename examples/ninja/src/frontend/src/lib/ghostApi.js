// Ghost API service for interacting with the Motoko backend

import { canisterId } from './canisters.js';
import { building } from '$app/environment';

// Determine if we're in local development or production
const isLocal = typeof window !== 'undefined' && 
  (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1');

// Build the base URL based on environment
const getBaseUrl = () => {
  if (building || process.env.NODE_ENV === "test") {
    return '/ghosts'; // Fallback for build/test
  }
  
  if (isLocal) {
    return `http://${canisterId}.raw.localhost:4943/ghosts`;
  } else {
    return `https://${canisterId}.ic0.app/ghosts`;
  }
};

const API_BASE = getBaseUrl();

export class GhostApi {
  /**
   * Get all ghosts
   * @returns {Promise<Array>} Array of ghost objects
   */
  static async getAllGhosts() {
    const response = await fetch(API_BASE, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to fetch ghosts: ${response.status} ${response.statusText}`);
    }
    
    return await response.json();
  }

  /**
   * Get a ghost by ID
   * @param {number} id - Ghost ID
   * @returns {Promise<Object>} Ghost object
   */
  static async getGhostById(id) {
    const response = await fetch(`${API_BASE}/${id}`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      },
    });
    
    if (!response.ok) {
      if (response.status === 404) {
        throw new Error(`Ghost with ID ${id} not found`);
      }
      throw new Error(`Failed to fetch ghost: ${response.status} ${response.statusText}`);
    }
    
    return await response.json();
  }

  /**
   * Convert file to base64
   * @param {File} file - Image file
   * @returns {Promise<string>} Base64 encoded string (without data URL prefix)
   */
  static fileToBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = () => {
        // Remove the data URL prefix (e.g., "data:image/png;base64,")
        const base64 = reader.result.split(',')[1];
        resolve(base64);
      };
      reader.onerror = error => reject(error);
    });
  }

  /**
   * Create a new ghost
   * @param {string} name - Ghost name
   * @param {File} imageFile - Ghost image file
   * @returns {Promise<Object>} Created ghost object
   */
  static async createGhost(name, imageFile) {
    if (!name || !name.trim()) {
      throw new Error('Ghost name is required');
    }

    if (!imageFile) {
      throw new Error('Ghost image is required');
    }

    // Validate file size (2MB limit)
    if (imageFile.size > 2 * 1024 * 1024) {
      throw new Error('Image file must be under 2MB');
    }

    // Validate file type
    if (!imageFile.type.startsWith('image/')) {
      throw new Error('File must be an image');
    }

    // Convert image to base64
    const base64Data = await this.fileToBase64(imageFile);
    
    const response = await fetch(API_BASE, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({ 
        name: name.trim(), 
        image: {
          data: base64Data,
          mimeType: imageFile.type
        }
      }),
    });
    
    if (!response.ok) {
      throw new Error(`Failed to create ghost: ${response.status} ${response.statusText}`);
    }
    
    return await response.json();
  }

  /**
   * Update a ghost
   * @param {number} id - Ghost ID
   * @param {string} name - New ghost name
   * @param {File} imageFile - New ghost image file (optional)
   * @returns {Promise<void>}
   */
  static async updateGhost(id, name, imageFile = null) {
    if (!name || !name.trim()) {
      throw new Error('Ghost name is required');
    }

    if (imageFile) {
      // Validate file size (2MB limit)
      if (imageFile.size > 2 * 1024 * 1024) {
        throw new Error('Image file must be under 2MB');
      }

      // Validate file type
      if (!imageFile.type.startsWith('image/')) {
        throw new Error('File must be an image');
      }
    }

    const requestBody = { name: name.trim() };
    
    if (imageFile) {
      const base64Data = await this.fileToBase64(imageFile);
      requestBody.image = {
        data: base64Data,
        mimeType: imageFile.type
      };
    }

    const response = await fetch(`${API_BASE}/${id}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody),
    });
    
    if (!response.ok) {
      if (response.status === 404) {
        throw new Error(`Ghost with ID ${id} not found`);
      }
      throw new Error(`Failed to update ghost: ${response.status} ${response.statusText}`);
    }
  }

  /**
   * Delete a ghost
   * @param {number} id - Ghost ID
   * @returns {Promise<void>}
   */
  static async deleteGhost(id) {
    const response = await fetch(`${API_BASE}/${id}`, {
      method: 'DELETE',
    });
    
    if (!response.ok) {
      if (response.status === 404) {
        throw new Error(`Ghost with ID ${id} not found`);
      }
      throw new Error(`Failed to delete ghost: ${response.status} ${response.statusText}`);
    }
  }

  /**
   * Get the image URL for a ghost
   * @param {number} id - Ghost ID
   * @param {boolean} bustCache - Whether to add cache-busting parameter
   * @returns {string} Image URL
   */
  static getImageUrl(id, bustCache = false) {
    if (building || process.env.NODE_ENV === "test") {
      return '/ghost-placeholder.svg'; // Fallback for build/test
    }
    
    let baseUrl;
    if (isLocal) {
      baseUrl = `http://${canisterId}.raw.localhost:4943/ghosts/${id}/image`;
    } else {
      baseUrl = `https://${canisterId}.ic0.app/ghosts/${id}/image`;
    }
    
    // Add cache-busting parameter if requested
    if (bustCache) {
      const timestamp = Date.now();
      baseUrl += `?_cb=${timestamp}`;
    }
    
    return baseUrl;
  }
}

export default GhostApi;
