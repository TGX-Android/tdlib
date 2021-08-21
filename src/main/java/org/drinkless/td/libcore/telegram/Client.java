/*
 * Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2021
 *
 * Distributed under the Boost Software License, Version 1.0. (See accompanying
 * file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 */

package org.drinkless.td.libcore.telegram;

import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.Keep;
import androidx.annotation.Nullable;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

/**
 * Main class for interaction with the TDLib.
 */
public final class Client implements Runnable {
    /**
     * Interface for handler for results of queries to TDLib and incoming updates from TDLib.
     */
    public interface ResultHandler {
        /**
         * Callback called on result of query to TDLib or incoming update from TDLib.
         *
         * @param object Result of query or update of type TdApi.Update about new events.
         */
        void onResult(TdApi.Object object);
    }

    /**
     * Interface for handler of exceptions thrown while invoking ResultHandler.
     * By default, all such exceptions are ignored.
     * All exceptions thrown from ExceptionHandler are ignored.
     */
    public interface ExceptionHandler {
        /**
         * Callback called on exceptions thrown while invoking ResultHandler.
         *
         * @param e Exception thrown by ResultHandler.
         */
        void onException(Throwable e);
    }

    public interface FatalErrorHandler {
        void onFatalError (@Nullable Client client, String errorMessage, boolean isLayerError);
    }

    /**
     * Sends a request to the TDLib.
     *
     * @param query            Object representing a query to the TDLib.
     * @param resultHandler    Result handler with onResult method which will be called with result
     *                         of the query or with TdApi.Error as parameter. If it is null, nothing
     *                         will be called.
     * @param exceptionHandler Exception handler with onException method which will be called on
     *                         exception thrown from resultHandler. If it is null, then
     *                         defaultExceptionHandler will be called.
     * @throws NullPointerException if query is null.
     */
    public void send(TdApi.Function query, ResultHandler resultHandler, ExceptionHandler exceptionHandler) {
        if (query == null) {
            throw new NullPointerException("query is null");
        }

        readLock.lock();
        try {
            if (isClientDestroyed) {
                if (resultHandler != null) {
                    handleResult(new TdApi.Error(500, "Client is closed"), query, 0, resultHandler, exceptionHandler);
                }
                return;
            }

            long queryId = currentQueryId.incrementAndGet();
            handlers.put(queryId, new Handler(query, resultHandler, exceptionHandler));
            NativeClient.clientSend(nativeClientId, queryId, query);
        } finally {
            readLock.unlock();
        }
    }

    /**
     * Sends a request to the TDLib with an empty ExceptionHandler.
     *
     * @param query         Object representing a query to the TDLib.
     * @param resultHandler Result handler with onResult method which will be called with result
     *                      of the query or with TdApi.Error as parameter. If it is null, then
     *                      defaultExceptionHandler will be called.
     * @throws NullPointerException if query is null.
     */
    public void send(TdApi.Function query, ResultHandler resultHandler) {
        send(query, resultHandler, null);
    }

    /**
     * Synchronously executes a TDLib request. Only a few marked accordingly requests can be executed synchronously.
     *
     * @param query Object representing a query to the TDLib.
     * @return request result.
     * @throws NullPointerException if query is null.
     */
    public static TdApi.Object execute(TdApi.Function query) {
        if (query == null) {
            throw new NullPointerException("query is null");
        }
        return NativeClient.clientExecute(query);
    }

    /**
     * Replaces handler for incoming updates from the TDLib.
     *
     * @param updatesHandler   Handler with onResult method which will be called for every incoming
     *                         update from the TDLib.
     * @param exceptionHandler Exception handler with onException method which will be called on
     *                         exception thrown from updatesHandler, if it is null, defaultExceptionHandler will be invoked.
     */
    public void setUpdatesHandler(ResultHandler updatesHandler, ExceptionHandler exceptionHandler) {
        handlers.put(0L, new Handler(null, updatesHandler, exceptionHandler));
    }

    /**
     * Replaces handler for incoming updates from the TDLib. Sets empty ExceptionHandler.
     *
     * @param updatesHandler Handler with onResult method which will be called for every incoming
     *                       update from the TDLib.
     */
    public void setUpdatesHandler(ResultHandler updatesHandler) {
        setUpdatesHandler(updatesHandler, null);
    }

    /**
     * Replaces default exception handler to be invoked on exceptions thrown from updatesHandler and all other ResultHandler.
     *
     * @param defaultExceptionHandler Default exception handler. If null Exceptions are ignored.
     */
    public void setDefaultExceptionHandler(Client.ExceptionHandler defaultExceptionHandler) {
        this.defaultExceptionHandler = defaultExceptionHandler;
    }

    public static void setFatalErrorHandler(Client.FatalErrorHandler fatalErrorHandler) {
        Client.fatalErrorHandler = fatalErrorHandler;
    }

    /**
     * Function for benchmarking number of queries per second which can handle the TDLib, ignore it.
     *
     * @param query   Object representing a query to the TDLib.
     * @param handler Result handler with onResult method which will be called with result
     *                of the query or with TdApi.Error as parameter.
     * @param count   Number of times to repeat the query.
     * @throws NullPointerException if query is null.
     */
    public void bench(TdApi.Function query, ResultHandler handler, int count) {
        if (query == null) {
            throw new NullPointerException("query is null");
        }

        for (int i = 0; i < count; i++) {
            send(query, handler);
        }
    }

    /**
     * Overridden method from Runnable, do not call it directly.
     */
    @Override
    public void run() {
        while (!stopFlag) {
            receiveQueries(300.0 /*seconds*/);
        }
        Log.d("DLTD", "Stop TDLib thread");
    }

    /**
     * Creates new Client.
     *
     * @param updatesHandler          Handler for incoming updates.
     * @param updatesExceptionHandler Handler for exceptions thrown from updatesHandler. If it is null, exceptions will be iggnored.
     * @param defaultExceptionHandler Default handler for exceptions thrown from all ResultHandler. If it is null, exceptions will be iggnored.
     * @return created Client
     */
    public static Client create(ResultHandler updatesHandler, ExceptionHandler updatesExceptionHandler, ExceptionHandler defaultExceptionHandler, boolean isDebug) {
        return new Client(updatesHandler, updatesExceptionHandler, defaultExceptionHandler, isDebug);
    }

    /**
     * Changes TDLib log verbosity.
     *
     * @deprecated As of TDLib 1.4.0 in favor of {@link TdApi.SetLogVerbosityLevel}, to be removed in the future.
     * @param newLogVerbosity New value of log verbosity. Must be non-negative.
     *                        Value 0 corresponds to android.util.Log.ASSERT,
     *                        value 1 corresponds to android.util.Log.ERROR,
     *                        value 2 corresponds to android.util.Log.WARNING,
     *                        value 3 corresponds to android.util.Log.INFO,
     *                        value 4 corresponds to android.util.Log.DEBUG,
     *                        value 5 corresponds to android.util.Log.VERBOSE,
     *                        value greater than 5 can be used to enable even more logging.
     *                        Default value of the log verbosity is 5.
     * @throws IllegalArgumentException if newLogVerbosity is negative.
     */
    @Deprecated
    public static void setLogVerbosityLevel(int newLogVerbosity) {
        if (newLogVerbosity < 0) {
            throw new IllegalArgumentException("newLogVerbosity can't be negative");
        }
        NativeClient.setLogVerbosityLevel(newLogVerbosity);
    }

    /**
     * Sets file path for writing TDLib internal log.
     * By default TDLib writes logs to the Android Log.
     * Use this method to write the log to a file instead.
     *
     * @deprecated As of TDLib 1.4.0 in favor of {@link TdApi.SetLogStream}, to be removed in the future.
     * @param filePath Path to a file for writing TDLib internal log. Use an empty path to
     *                 switch back to logging to the Android Log.
     * @return whether opening the log file succeeded
     */
    @Deprecated
    public static boolean setLogFilePath(String filePath) {
        return NativeClient.setLogFilePath(filePath);
    }

    /**
     * Changes maximum size of TDLib log file.
     *
     * @deprecated As of TDLib 1.4.0 in favor of {@link TdApi.SetLogStream}, to be removed in the future.
     * @param maxFileSize Maximum size of the file to where the internal TDLib log is written
     *                    before the file will be auto-rotated. Must be positive. Defaults to 10 MB.
     * @throws IllegalArgumentException if max_file_size is non-positive.
     */
    @Deprecated
    public static void setLogMaxFileSize(long maxFileSize) {
        if (maxFileSize <= 0) {
            throw new IllegalArgumentException("maxFileSize should be positive");
        }
        NativeClient.setLogMaxFileSize(maxFileSize);
    }

    /**
     * Closes Client.
     */
    public void close() {
        writeLock.lock();
        try {
            if (isClientDestroyed) {
                return;
            }
            if (!stopFlag) {
                send(new TdApi.Close(), null);
            }
            isClientDestroyed = true;
            while (!stopFlag) {
                Thread.yield();
            }
            if (handlers.size() != 1) {
                receiveQueries(0.0);

                for (Long key : handlers.keySet()) {
                    if (key != 0) {
                        processResult(key, new TdApi.Error(500, "Client is closed"));
                    }
                }
            }
            NativeClient.destroyClient(nativeClientId);
            clientCount.decrementAndGet();
        } finally {
            writeLock.unlock();
        }
    }

    public static long getClientCount () {
        return clientCount.get();
    }

    private String buildLostPromiseError (@Nullable TdApi.Function query, long queryTime, TdApi.Error error) {
        StringBuilder b = new StringBuilder("#").append(error.code).append(": ").append(error.message).append(" (").append(clientCount.get()).append(")");
        if (isDebug)
            b.append(" (debug)");
        if (queryTime != -1)
            b.append(" (in ").append(SystemClock.uptimeMillis() - queryTime).append("ms)");
        b.append(": ");
        if (query != null) {
            b.append(query.toString().replace("\n", "\\n"));
        } else {
            b.append("updatesHandler");
        }
        return b.toString();
    }

    /**
     * This function is called from the JNI when a fatal error happens to provide a better error message.
     * It shouldn't return. Do not call it directly.
     *
     * @param errorMessage Error message.
     */
    @Keep
    static void onFatalError(String errorMessage) {
        onFatalError(null, errorMessage, false);
    }

    private static void onFatalError (@Nullable Client client, String errorMessage, boolean isLayerError) {
        if (fatalErrorHandler != null) {
            fatalErrorHandler.onFatalError(client, errorMessage, isLayerError);
        }
        final class ThrowError implements Runnable {
            private final String errorMessage;

            private ThrowError(String errorMessage) {
                this.errorMessage = errorMessage;
            }

            @Override
            public void run() {
                if (isExternalError(errorMessage)) {
                    processExternalError();
                    return;
                }

                throw new ClientException_55("TDLib fatal error (" + clientCount.get() + "): " + errorMessage);
            }

            private void processExternalError() {
                throw new ExternalClientException_55("Fatal error (" + clientCount.get() + "): " + errorMessage);
            }
        }

        new Thread(new ThrowError(errorMessage), "TDLib fatal error thread").start();
        while (true) {
            try {
                Thread.sleep(1000 /* milliseconds */);
            } catch (InterruptedException ignore) {
                Thread.currentThread().interrupt();
            }
        }
    }

    public static boolean isDatabaseBrokenError(String message) {
        return message.contains("Wrong key or database is corrupted") ||
          message.contains("SQL logic error or missing database") ||
          message.contains("database disk image is malformed") ||
          message.contains("file is encrypted or is not a database") ||
          message.contains("unsupported file format");
    }

    public static boolean isDiskFullError(String message) {
        return message.contains("PosixError : No space left on device") ||
          message.contains("database or disk is full");
    }

    public static boolean isExternalError(String message) {
        return isDatabaseBrokenError(message) || isDiskFullError(message) ||
          message.contains("I/O error");
    }

    private static final class ClientException_55 extends RuntimeException {
        private ClientException_55 (String message) {
            super(message);
        }
    }

    private static final class ExternalClientException_55 extends RuntimeException {
        public ExternalClientException_55 (String message) {
            super(message);
        }
    }

    private final ReadWriteLock readWriteLock = new ReentrantReadWriteLock();
    private final Lock readLock = readWriteLock.readLock();
    private final Lock writeLock = readWriteLock.writeLock();

    private static final AtomicLong clientCount = new AtomicLong();

    private volatile boolean stopFlag = false;
    private volatile boolean isClientDestroyed = false;
    private final long nativeClientId;

    private final ConcurrentHashMap<Long, Handler> handlers = new ConcurrentHashMap<Long, Handler>();
    private final AtomicLong currentQueryId = new AtomicLong();

    private volatile ExceptionHandler defaultExceptionHandler = null;
    private static volatile FatalErrorHandler fatalErrorHandler = null;

    private static final int MAX_EVENTS = 1000;
    private final long[] eventIds = new long[MAX_EVENTS];
    private final TdApi.Object[] events = new TdApi.Object[MAX_EVENTS];

    private static class Handler {
        final TdApi.Function query;
        final long queryTime;
        final ResultHandler resultHandler;
        final ExceptionHandler exceptionHandler;

        Handler (TdApi.Function query, ResultHandler resultHandler, ExceptionHandler exceptionHandler) {
            this.query = query;
            this.queryTime = query != null ? SystemClock.uptimeMillis() : -1;
            this.resultHandler = resultHandler;
            this.exceptionHandler = exceptionHandler;
        }
    }

    private final Thread thread;
    private final boolean isDebug;

    public Thread getThread () {
        return thread;
    }

    private Client(ResultHandler updatesHandler, ExceptionHandler updateExceptionHandler, ExceptionHandler defaultExceptionHandler, boolean isDebug) {
        clientCount.incrementAndGet();
        this.isDebug = isDebug;
        nativeClientId = NativeClient.createClient();
        handlers.put(0L, new Handler(null, updatesHandler, updateExceptionHandler));
        this.defaultExceptionHandler = defaultExceptionHandler;
        thread = new Thread(this, "TDLib thread");
        thread.start();
    }

    @Override
    protected void finalize() throws Throwable {
        try {
            close();
        } finally {
            super.finalize();
        }
    }

    private void processResult(long id, TdApi.Object object) {
        Handler handler;
        if (id == 0) {
            // update handler stays forever
            handler = handlers.get(id);

            if (object instanceof TdApi.UpdateAuthorizationState) {
                if (((TdApi.UpdateAuthorizationState) object).authorizationState instanceof TdApi.AuthorizationStateClosed) {
                    stopFlag = true;
                }
            }
        } else {
            handler = handlers.remove(id);
        }
        if (handler == null) {
            Log.e("DLTD", "Can't find handler for the result " + id + " -- ignore result");
            return;
        }

        handleResult(object, handler.query, handler.queryTime, handler.resultHandler, handler.exceptionHandler);
    }

    private void handleResult (TdApi.Object object, @Nullable TdApi.Function query, long queryTime, ResultHandler resultHandler, ExceptionHandler exceptionHandler) {
        if (resultHandler == null) {
            return;
        }

        if (object instanceof TdApi.Error) {
            TdApi.Error error = (TdApi.Error) object;
            if (error.code == 0 && "Lost promise".equals(error.message)) {
                onFatalError(this, buildLostPromiseError(query, queryTime, error), true);
            }
        }

        try {
            resultHandler.onResult(object);
        } catch (Throwable cause) {
            if (exceptionHandler == null) {
                exceptionHandler = defaultExceptionHandler;
            }
            if (exceptionHandler != null) {
                try {
                    exceptionHandler.onException(cause);
                } catch (Throwable ignored) {
                }
            }
        }
    }

    private void receiveQueries(double timeout) {
        int resultN = NativeClient.clientReceive(nativeClientId, eventIds, events, timeout);
        for (int i = 0; i < resultN; i++) {
            processResult(eventIds[i], events[i]);
            events[i] = null;
        }
    }
}