export interface BarewireConfig {
  /**
   * The hostname of your Barewire edge proxy.
   * Example: 'your-barewire-proxy.cloudflareworkers.dev'
   */
  barewireHost: string;
  /**
   * Optional: A function to transform the original URL into the Barewire proxy URL.
   * By default, it prepends the full original URL (encoded) to the barewireHost path.
   * Example: https://barewire.mycompany.com/https%3A%2F%2Fapi.example.com%2Fresource
   *
   * @param originalUrl The URL being fetched.
   * @param barewireHost The configured barewireHost.
   * @returns The transformed URL that should point to the Barewire proxy.
   */
  urlTransformer?: (originalUrl: URL, barewireHost: string) => URL;
}

// Store the original fetch function
let originalFetch: typeof globalThis.fetch | undefined;

/**
 * Initializes and registers a fetch interceptor to route all requests through the Barewire edge proxy.
 *
 * @param config Configuration for the Barewire integration.
 * @returns A function to disable the interceptor and restore the original fetch.
 * @throws {Error} If Barewire is already initialized or configuration is invalid.
 */
export function setupBarewireFetchInterceptor(config: BarewireConfig): () => void {
  if (originalFetch !== undefined) {
    throw new Error('Barewire fetch interceptor is already active. Call the returned disable function first.');
  }

  if (!config.barewireHost) {
    throw new Error('BarewireConfig.barewireHost is required.');
  }

  // Ensure barewireHost does not have a scheme (e.g., "https://")
  const barewireHost = config.barewireHost.replace(/^(https?:\/\/)/, '');
  if (!barewireHost) {
    throw new Error('BarewireConfig.barewireHost is invalid after scheme removal.');
  }

  originalFetch = globalThis.fetch;

  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    let requestUrl: URL;
    let requestInit: RequestInit | undefined;
    let originalInputRequest: Request | undefined;

    if (input instanceof Request) {
      originalInputRequest = input;
      requestUrl = new URL(originalInputRequest.url);
      // Extract original request properties into a new RequestInit object
      requestInit = {
        method: originalInputRequest.method,
        headers: originalInputRequest.headers,
        body: originalInputRequest.body,
        mode: originalInputRequest.mode,
        credentials: originalInputRequest.credentials,
        cache: originalInputRequest.cache,
        // When proxying, it's often better to set redirect to 'manual'
        // so the proxy can handle redirects, or the client explicitly
        // processes 3xx responses.
        redirect: originalInputRequest.redirect === 'follow' ? 'manual' : originalInputRequest.redirect,
        referrer: originalInputRequest.referrer,
        referrerPolicy: originalInputRequest.referrerPolicy,
        integrity: originalInputRequest.integrity,
        keepalive: originalInputRequest.keepalive,
        signal: originalInputRequest.signal,
        // The `window` property is typically null for requests not associated with a window
        // and cannot be directly copied to a new RequestInit for cross-origin fetches.
        // if (originalInputRequest.window) requestInit.window = originalInputRequest.window as any;
      };
      // Merge any provided `init` options, overriding original request properties
      if (init) {
        requestInit = { ...requestInit, ...init };
      }
    } else if (typeof input === 'string') {
      requestUrl = new URL(input);
      requestInit = init;
    } else { // input is URL
      requestUrl = input;
      requestInit = init;
    }

    // Only intercept HTTP/HTTPS requests that are not already targeting the Barewire host itself.
    // This prevents recursive proxying.
    if (
      (requestUrl.protocol === 'http:' || requestUrl.protocol === 'https:') &&
      !requestUrl.hostname.endsWith(barewireHost)
    ) {
      const transformedUrl = config.urlTransformer
        ? config.urlTransformer(requestUrl, barewireHost)
        : defaultUrlTransformer(requestUrl, barewireHost);

      // Call original fetch with the transformed URL and the potentially modified init.
      // If original input was a Request object, all its properties are now in `requestInit`.
      // If original input was string/URL, `requestInit` is just the `init` argument.
      return originalFetch(transformedUrl.toString(), requestInit);
    }

    // For non-intercepted requests (e.g., non-HTTP/HTTPS, or already targeting Barewire proxy),
    // use the original fetch with original input and init.
    return originalFetch(input, init);
  };

  /**
   * Disables the Barewire interceptor and restores the original fetch function.
   */
  return () => {
    if (originalFetch) {
      globalThis.fetch = originalFetch;
      originalFetch = undefined; // Clear the stored reference
    }
  };
}

/**
 * Default URL transformer for Barewire.
 * Encodes the full original URL (scheme, host, path, query) into the Barewire proxy path.
 *
 * Example:
 * originalUrl: https://api.example.com/resource?q=1
 * barewireHost: barewire.mycompany.com
 * Result: https://barewire.mycompany.com/https%3A%2F%2Fapi.example.com%2Fresource%3Fq%3D1
 */
function defaultUrlTransformer(originalUrl: URL, barewireHost: string): URL {
  const encodedOriginalUrl = encodeURIComponent(originalUrl.toString());
  // Use 'https' for the proxy request itself for security
  return new URL(`https://${barewireHost}/${encodedOriginalUrl}`);
}