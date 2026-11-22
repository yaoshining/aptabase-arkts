import { common } from '@kit.AbilityKit';
import { url, util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import lazy { rcp } from '@kit.RemoteCommunicationKit';
import { HAR_VERSION } from '../../../BuildProfile';
import { EnvironmentInfo } from './EnvironmentInfo';

export enum TrackingMode {
  asDebug,
  asRelease,
  readFromEnvironment,
}

export interface InitOptions {
  host?: string | null;
  trackingMode?: TrackingMode;
  appVersion?: string | null;
}

export type EventProperties = ReadonlyMap<string, string | number>;

const SESSION_TIMEOUT_MS = 60 * 60 * 1000;
const MAX_IN_FLIGHT = 5;
const MAX_PENDING = 64;
const REQUEST_TIMEOUT_MS = 5000;
const LOG_DOMAIN = 0x0000;
const LOG_TAG = 'Aptabase';
const EVENT_PATH = '/api/v0/event';

class SystemProps extends EnvironmentInfo {
  readonly sdkVersion: string = 'aptabase-arkts@' + HAR_VERSION;

  constructor(env: EnvironmentInfo, mode: TrackingMode, appVersion?: string | null) {
    super(
      mode === TrackingMode.readFromEnvironment ? env.isDebug : mode === TrackingMode.asDebug,
      env.osName,
      env.osVersion,
      env.locale,
      appVersion ?? env.appVersion,
      env.appBuildNumber,
      env.deviceModel,
    );
  }
}

interface TrackingConfig {
  appKey: string;
  endpoint: string;
  systemProps: SystemProps;
}

interface PendingEvent {
  config: TrackingConfig;
  body: string;
}

interface EventBody {
  timestamp: string;
  sessionId: string;
  eventName: string;
  systemProps: SystemProps;
  props: Record<string, string | number>;
}

interface EventRequest {
  send: (endpoint: string, headers: Record<string, string>, body: string) => Promise<number>;
  close: (cancel: boolean) => void;
}

export class Aptabase {
  static readonly instance: Aptabase = new Aptabase();

  private config?: TrackingConfig;
  private sessionId: string = '';
  private lastTouched: number = 0;
  private readonly pending: PendingEvent[] = [];
  private readonly requests: Set<EventRequest> = new Set();

  private constructor() {}

  initialize(context: common.Context, appKey: string, opts?: InitOptions | null): void {
    this.stop();
    const parts = appKey.split('-');
    if (parts.length !== 3 || parts[0] !== 'A' || !/^[a-zA-Z0-9]+$/.test(parts[2])) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Invalid App Key. Tracking is disabled.');
      return;
    }

    const endpoint = resolveEndpoint(parts[1], opts?.host);
    if (endpoint === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Invalid Aptabase region or self-hosted URL. Tracking is disabled.');
      return;
    }

    try {
      const env = EnvironmentInfo.get(context);
      const mode = opts?.trackingMode ?? TrackingMode.readFromEnvironment;
      const systemProps = new SystemProps(env, mode, opts?.appVersion);
      this.config = { appKey, endpoint, systemProps };
    } catch (_) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Could not read application metadata. Tracking is disabled.');
    }
  }

  stop(): void {
    this.config = undefined;
    this.sessionId = '';
    this.lastTouched = 0;
    this.pending.length = 0;
    this.requests.forEach((request: EventRequest) => this.closeRequest(request, true));
    this.requests.clear();
  }

  trackEvent(eventName: string, props?: EventProperties): void {
    const config = this.config;
    if (config === undefined || this.pending.length >= MAX_PENDING) {
      return;
    }

    const now = Date.now();
    if (this.sessionId === '' || now - this.lastTouched > SESSION_TIMEOUT_MS) {
      this.sessionId = util.generateRandomUUID().toLowerCase();
    }
    this.lastTouched = now;

    const body: EventBody = {
      timestamp: new Date(now).toISOString().slice(0, 19) + 'Z',
      sessionId: this.sessionId,
      eventName,
      systemProps: config.systemProps,
      props: toJsonProperties(props),
    };
    this.pending.push({ config, body: JSON.stringify(body) });
    this.drain();
  }

  private drain(): void {
    while (this.requests.size < MAX_IN_FLIGHT && this.pending.length > 0) {
      const event = this.pending.shift();
      if (event === undefined) {
        return;
      }
      void this.send(event).finally(() => {
        if (this.config === event.config) {
          this.drain();
        }
      });
    }
  }

  private async send(event: PendingEvent): Promise<void> {
    let connection: EventRequest | undefined;
    try {
      connection = createEventRequest();
      this.requests.add(connection);
      const headers: Record<string, string> = {
        'App-Key': event.config.appKey,
        'Content-Type': 'application/json',
      };
      const status = await connection.send(event.config.endpoint, headers, event.body);
      if (this.requests.has(connection) && (status < 200 || status >= 300)) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'Event request returned HTTP %{public}d.', status);
      }
    } catch (_) {
      if (connection === undefined || this.requests.has(connection)) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'Event request failed.');
      }
    } finally {
      if (connection !== undefined && this.requests.delete(connection)) {
        this.closeRequest(connection, false);
      }
    }
  }

  private closeRequest(request: EventRequest, cancel: boolean): void {
    try {
      request.close(cancel);
    } catch (_) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Could not release the HTTP request.');
    }
  }
}

function createEventRequest(): EventRequest {
  if (canIUse('SystemCapability.Collaboration.RemoteCommunication')) {
    const session = rcp.createSession({
      requestConfiguration: {
        transfer: {
          timeout: { connectMs: REQUEST_TIMEOUT_MS, inactivityMs: REQUEST_TIMEOUT_MS },
        },
      },
    });
    const connection: EventRequest = {
      send: async (endpoint: string, headers: Record<string, string>, body: string): Promise<number> => {
        const response = await session.fetch(new rcp.Request(endpoint, 'POST', headers, body));
        return response.statusCode;
      },
      close: (cancel: boolean): void => {
        try {
          if (cancel) {
            session.cancel();
          }
        } finally {
          session.close();
        }
      },
    };
    return connection;
  }

  const request = http.createHttp();
  const connection: EventRequest = {
    send: async (endpoint: string, headers: Record<string, string>, body: string): Promise<number> => {
      const response = await request.request(endpoint, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        usingCache: false,
        connectTimeout: REQUEST_TIMEOUT_MS,
        readTimeout: REQUEST_TIMEOUT_MS,
      });
      return response.responseCode;
    },
    close: (_cancel: boolean): void => request.destroy(),
  };
  return connection;
}

function toJsonProperties(props?: EventProperties): Record<string, string | number> {
  if (props === undefined || props.size === 0) {
    return {};
  }

  // Decode our own JSON to preserve property names such as "__proto__" as data.
  const entries: string[] = [];
  props.forEach((value, key) => {
    entries.push(JSON.stringify(key) + ':' + JSON.stringify(value));
  });
  return JSON.parse('{' + entries.join(',') + '}') as Record<string, string | number>;
}

function resolveEndpoint(region: string, host?: string | null): string | undefined {
  switch (region) {
    case 'US':
      return 'https://us.aptabase.com' + EVENT_PATH;
    case 'EU':
      return 'https://eu.aptabase.com' + EVENT_PATH;
    case 'DEV':
      return 'http://localhost:3000' + EVENT_PATH;
    case 'SH':
      if (!host || !/^https?:\/\//i.test(host.trim())) {
        return undefined;
      }
      try {
        const parsed = url.URL.parseURL(host.trim());
        if (!parsed.hostname || parsed.username || parsed.password || parsed.search || parsed.hash) {
          return undefined;
        }
        return parsed.href.replace(/\/+$/, '') + EVENT_PATH;
      } catch (_) {
        return undefined;
      }
    default:
      return undefined;
  }
}
