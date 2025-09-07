import { AsyncLocalStorage } from 'async_hooks';
import winston from 'winston';
import logger from './logger'; // The default logger

interface RequestContext {
  logger: winston.Logger;
}

const asyncLocalStorage = new AsyncLocalStorage<RequestContext>();

export function getLogger(): winston.Logger {
  const context = asyncLocalStorage.getStore();
  return context ? context.logger : logger;
}

export function runWithRequestLogger<T>(logger: winston.Logger, fn: () => T): T {
  return asyncLocalStorage.run({ logger }, fn);
}
