// SPDX-License-Identifier: Apache-2.0
import { createRoot } from 'react-dom/client';
import { MockPortal } from '@openan/portal-sdk/standalone';
import HelloPortal from './index.jsx';

createRoot(document.getElementById('root')).render(<MockPortal><HelloPortal /></MockPortal>);
