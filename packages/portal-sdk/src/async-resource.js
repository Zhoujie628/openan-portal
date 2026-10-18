// SPDX-License-Identifier: Apache-2.0
export const DEFAULT_PLUGIN_TIMEOUT_MS = 15000;

/** Bound even non-cancellable imports; cancellable resources receive a signal. */
export function withPluginDeadline(work, { signal, timeoutMs = DEFAULT_PLUGIN_TIMEOUT_MS, label = 'Plugin resource' } = {}) {
    if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) return Promise.reject(new Error('Plugin timeout must be positive'));
    const controller = new AbortController();
    return new Promise((resolve, reject) => {
        let settled = false;
        let timer;
        const finish = (error, value) => {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            signal?.removeEventListener('abort', cancel);
            if (error) { controller.abort(error); reject(error); }
            else resolve(value);
        };
        const cancel = () => finish(signal.reason || new Error(`${label} cancelled`));
        if (signal?.aborted) { cancel(); return; }
        signal?.addEventListener('abort', cancel, { once: true });
        timer = setTimeout(() => finish(new Error(`${label} timed out after ${timeoutMs}ms`)), timeoutMs);
        Promise.resolve().then(() => {
            controller.signal.throwIfAborted();
            return work(controller.signal);
        }).then(value => finish(null, value), error => finish(error || new Error(`${label} failed`)));
    });
}
