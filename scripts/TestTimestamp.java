/*
 * Copyright (C) 2022 Red Hat, Inc.
 * Written by Andrew Hughes <gnu.andrew@redhat.com>, 2022
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import java.time.Instant;
import java.time.format.DateTimeParseException;

public class TestTimestamp {
    public static void main(String[] args) {
        int failures=0;

        if (args.length == 0) {
            System.err.println("TestTimestamp <timestamp-list>");
            System.exit(1);
        }

        for (String arg : args) {
            try {
                Instant parsed = Instant.parse(arg);
                System.out.printf("Successfully parsed %s as %s\n", arg, parsed);
            } catch (DateTimeParseException e) {
                System.err.printf("FAILURE: Exception %s when parsing %s\n", e, arg);
                failures++;
            }
        }

        if (failures > 0) {
            System.err.printf("%d timestamp failures\n", failures);
            System.exit(1 + failures);
        }
    }
}
