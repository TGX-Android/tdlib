/*
 * This file is a part of Telegram X
 * Copyright © 2014-2022 (tgx-android@pm.me)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * File created on 20/09/2022, 18:25.
 */

package org.drinkless.td.libcore.telegram;

import androidx.annotation.Nullable;

public abstract class ClientError extends RuntimeException {
  private static String stripPrivateData (String message) {
    if (message == null || message.length() == 0)
      return message;
    int newStart = 0;
    int tagStart = -1;
    for (int i = 0; i < message.length(); i++) {
      char c = message.charAt(i);
      if (c == '[') {
        tagStart = i;
      } else if (c == ']' && tagStart != -1) {
        newStart = i + 1;
        tagStart = -1;
      } else if (tagStart == -1) {
        newStart = i;
        if (!Character.isWhitespace(c)) {
          break;
        }
      }
    }
    if (newStart > 0) {
      message = message.substring(newStart);
    }
    StringBuilder b = new StringBuilder(message.length());
    int quoteOpenIndex = -1;
    char prevChar = 0;
    for (int i = 0; i < message.length(); i++) {
      char c = message.charAt(i);
      if (c == '"' && prevChar != '\\') {
        if (quoteOpenIndex == -1) {
          quoteOpenIndex = i;
        } else {
          b.append("STRING");
        }
      } else if (quoteOpenIndex == -1) {
        if (c == '@') {
          b.append("AT");
        } else if (c != '`') {
          b.append(c);
        }
      }
      prevChar = c;
    }
    return b.toString().replaceAll("[0-9]+", "X");
  }

  @Nullable
  private static StackTraceElement findSourceFileAndLineNumber (String message) {
    // sample message: [ 0][t 7][1663524892.910522937][StickersManager.cpp:327][#3][!Td]  Check `Unreacheable` failed
    if (message == null || message.length() == 0)
      return null;
    int tagCount = 0;
    int tagStart = -1;
    for (int i = 0; i < message.length(); i++) {
      char c = message.charAt(i);
      if (c == '[') {
        tagStart = i;
      } else if (c == ']') {
        if (tagStart != -1) {
          int tagEnd = i;
          /*switch (tagCount) {
            case 0: break; // [ 0] — logging level
            case 1: break; // [t 7] — thread id
            case 2: break; // [1663524892.910522937] — time
            case 3: break; // [StickersManager.cpp:327] - file & line
            case 4: break; // [#3] — instance id
            case 5: break; // [!Td]
          }*/
          if (tagCount == 3) {
            // Extract everything between `[` and `]`
            String fileName = message.substring(tagStart + 1, tagEnd);
            int splitIndex = fileName.indexOf(':');
            int lineNumber = 0;
            if (splitIndex != -1) {
              String lineNumberStr = fileName.substring(splitIndex + 1);
              fileName = fileName.substring(0, splitIndex);
              try {
                lineNumber = Integer.parseInt(lineNumberStr);
              } catch (NumberFormatException ignored) { }
            }
            if (fileName.matches("^[A-Za-z_0-9.]+[^.]$")) {
              splitIndex = fileName.indexOf('.');
              String declaringClass = fileName.substring(0, splitIndex);
              return new StackTraceElement("libtdjni.so", declaringClass, declaringClass + ".java", lineNumber);
            }
            return null;
          }
          tagStart = -1;
          tagCount++;
        }
      } else if (tagStart == -1) {
        if (!Character.isWhitespace(c)) {
          break;
        }
      }
    }
    return null;
  }

  private static String buildMessage (String prefix, String message, long clientCount, boolean stripPotentiallyPrivateData) {
    StringBuilder b = new StringBuilder();
    if (prefix != null) {
      b.append(prefix);
    }
    if (clientCount > 0 && !stripPotentiallyPrivateData) {
      if (b.length() > 0) {
        b.append(" ");
      }
      b.append("(").append(clientCount).append(")");
    }
    if (message != null && message.length() > 0) {
      if (b.length() > 0) {
        b.append(": ");
      }
      if (stripPotentiallyPrivateData) {
        b.append(stripPrivateData(message));
      } else {
        b.append(message);
      }
    }
    return b.toString();
  }

  protected final String prefix, message;
  protected final long clientCount;
  protected final boolean isStripped;

  public ClientError (String prefix, String message, long clientCount) {
    this(prefix, message, clientCount, false);
  }

  public ClientError (String prefix, String message, long clientCount, boolean stripPotentiallyPrivateData) {
    super(buildMessage(prefix, message, clientCount, stripPotentiallyPrivateData));
    this.prefix = prefix;
    this.message = message;
    this.clientCount = clientCount;
    this.isStripped = stripPotentiallyPrivateData;
  }

  public final ClientError withoutPotentiallyPrivateData () {
    if (isStripped) {
      return this;
    }
    ClientError error = stripPotentiallyPrivateData();
    StackTraceElement[] elements = this.getStackTrace();
    StackTraceElement tdjniElement = findSourceFileAndLineNumber(message);
    if (tdjniElement != null) {
      StackTraceElement[] newElements = new StackTraceElement[elements.length + 1];
      newElements[0] = tdjniElement;
      System.arraycopy(elements, 0, newElements, 1, elements.length);
      elements = newElements;
    }
    error.setStackTrace(elements);
    return error;
  }

  protected abstract ClientError stripPotentiallyPrivateData ();
}
