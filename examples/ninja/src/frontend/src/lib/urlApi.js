// URL Shortener API service for interacting with the Motoko backend

import { canisterId } from './canisters.js';
import { building } from '$app/environment';

// Determine if we're in local development or production
const isLocal = typeof window !== 'undefined' && 
  (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1');

// Build the base URL based on environment
const getBaseUrl = () => {
  if (building || process.env.NODE_ENV === "test") {
    return '/'; // Fallback for build/test
  }
  
  if (isLocal) {
    return `http://${canisterId}.raw.localhost:4943`;
  } else {
    return `https://${canisterId}.ic0.app`;
  }
};

const API_BASE = getBaseUrl();

export class UrlApi {
  /**
   * Get all shortened URLs
   * @returns {Promise<Array>} Array of URL objects
   */
  static async getAllUrls() {
    const response = await fetch(`${API_BASE}/urls`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to fetch URLs: ${response.status} ${response.statusText}`);
    }
    
    return await response.json();
  }

  /**
   * Create a shortened URL
   * @param {string} originalUrl - The original long URL
   * @param {string|null} customSlug - Optional custom short code
   * @returns {Promise<Object>} Created URL object
   */
  static async createShortUrl(originalUrl, customSlug = null) {
    if (!originalUrl || !originalUrl.trim()) {
      throw new Error('Original URL is required');
    }

    // Validate URL format
    try {
      new URL(originalUrl);
    } catch {
      throw new Error('Invalid URL format');
    }

    const body = customSlug 
      ? `url=${encodeURIComponent(originalUrl)}&slug=${encodeURIComponent(customSlug)}`
      : originalUrl;

    const response = await fetch(`${API_BASE}/shorten`, {
      method: 'POST',
      headers: {
        'Content-Type': customSlug ? 'application/x-www-form-urlencoded' : 'text/plain',
      },
      body: body,
    });
    
    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to create short URL: ${errorText}`);
    }
    
    return await response.json();
  }

  /**
   * Delete a shortened URL
   * @param {number} id - URL ID
   * @returns {Promise<void>}
   */
  static async deleteUrl(id) {
    const response = await fetch(`${API_BASE}/urls/${id}`, {
      method: 'DELETE',
    });
    
    if (!response.ok) {
      if (response.status === 404) {
        throw new Error(`URL with ID ${id} not found`);
      }
      throw new Error(`Failed to delete URL: ${response.status} ${response.statusText}`);
    }
  }

  /**
   * Get the full short URL for a given short code
   * @param {string} shortCode - The short code
   * @returns {string} Full short URL
   */
  static getShortUrl(shortCode) {
    return `${API_BASE}/s/${shortCode}`;
  }

  /**
   * Get URL statistics
   * @param {string} shortCode - The short code
   * @returns {Promise<Object>} URL statistics
   */
  static async getUrlStats(shortCode) {
    const response = await fetch(`${API_BASE}/s/${shortCode}/stats`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      },
    });
    
    if (!response.ok) {
      if (response.status === 404) {
        throw new Error(`Short URL ${shortCode} not found`);
      }
      throw new Error(`Failed to fetch URL stats: ${response.status} ${response.statusText}`);
    }
    
    return await response.json();
  }
}

export default UrlApi;
