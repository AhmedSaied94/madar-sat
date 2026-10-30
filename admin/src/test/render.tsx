import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, type RenderOptions, type RenderResult } from '@testing-library/react';
import type { ReactElement, ReactNode } from 'react';
import { MemoryRouter } from 'react-router-dom';

interface RtlRenderOptions extends Omit<RenderOptions, 'wrapper'> {
  route?: string;
  wrapper?: (props: { children: ReactNode }) => ReactElement;
}

/**
 * Renders inside an RTL root (as admin/index.html does) with a fresh query client and a memory router.
 * `wrapper` adds app providers (session, toasts) inside the router.
 */
export function renderRtl(ui: ReactElement, { route = '/', wrapper: Inner, ...options }: RtlRenderOptions = {}): RenderResult {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });

  function Providers({ children }: { children: ReactNode }): ReactElement {
    return (
      <div dir="rtl" lang="ar">
        <QueryClientProvider client={queryClient}>
          <MemoryRouter initialEntries={[route]}>{Inner ? <Inner>{children}</Inner> : children}</MemoryRouter>
        </QueryClientProvider>
      </div>
    );
  }

  return render(ui, { wrapper: Providers, ...options });
}
