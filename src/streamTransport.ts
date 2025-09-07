import Transport from 'winston-transport';
import { Response } from 'express';

interface StreamTransportOptions extends Transport.TransportStreamOptions {
  res: Response;
}

export class StreamTransport extends Transport {
  private res: Response;

  constructor(opts: StreamTransportOptions) {
    super(opts);
    this.res = opts.res;
  }

  log(info: any, callback: () => void) {
    setImmediate(() => {
      this.emit('logged', info);
    });

    const message = info.message || '';
    // Also include any metadata in the log output
    const splat = info[Symbol.for('splat')];
    const meta = splat && splat.length ? ` ${JSON.stringify(splat)}` : '';

    if (!this.res.writableEnded) {
        this.res.write(`<pre>${new Date().toISOString()} - ${info.level.toUpperCase()}: ${message}${meta}</pre>`);
    }

    callback();
  }
}
