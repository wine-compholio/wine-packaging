/*
 * Wrapper to start Wine executable
 *
 * Copyright 2015 Michael Müller
 * Copyright 2016 Sebastian Lackner
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#include <Cocoa/Cocoa.h>
#include <unistd.h>
#include <stdio.h>

static BOOL wine_started = FALSE;

static void start_wine()
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];

    if ([arguments count] <= 1)
    {
        /* If no arguments have been passed, start a terminal */
        NSString *start_script = [NSString stringWithFormat:@"%@/start-script.sh", bundle.resourcePath];
        NSString *wine_bin_dir = [NSString stringWithFormat:@"%@/wine/bin", bundle.resourcePath];

        /* Let's talk with the terminal to open a new window */
        NSString *script = [NSString stringWithFormat:
             @"tell application \"Terminal\" to do script \
             \"export PATH=\\\"%@\\\":$PATH; source \\\"%@\\\"\"", wine_bin_dir, start_script];

        NSAppleScript *as = [[NSAppleScript alloc] initWithSource: script];
        [as executeAndReturnError:nil];

        /* We can now terminate our self */
        [NSApp terminate:nil];
    }
    else
    {
        NSString *wine_bin = [NSString stringWithFormat:@"%@/wine/bin/wine", bundle.resourcePath];
        [NSTask launchedTaskWithLaunchPath:wine_bin arguments:arguments];
        /* Now wait till we loose focus */
    }

    wine_started = TRUE;
}

static void open_with_wine(NSString *filename)
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *wine_bin = [NSString stringWithFormat:@"%@/wine/bin/wine", bundle.resourcePath];
    NSTask *task = [NSTask new];

    [task setLaunchPath:wine_bin];
    [task setArguments:[NSArray arrayWithObjects:filename, nil]];
    [task setCurrentDirectoryPath:[filename stringByDeletingLastPathComponent]];
    [task launch];
    [task release];

    wine_started = TRUE;
}

@interface MyDelegate : NSObject <NSApplicationDelegate>
@end

@implementation MyDelegate

- (id)init
{
    if ((self = [super init]))
    {
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
            selector:@selector(appDeactivated:)
            name:NSWorkspaceDidDeactivateApplicationNotification
            object:nil];
    }
    return self;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    open_with_wine(filename);
    return TRUE;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    /* In case wine was not started yet (for example through openFile) */
    if (!wine_started) start_wine();
}

- (void)appDeactivated:(NSNotification *)notification
{
    /* The user changed the window or the wine application created its
     * on window, we can terminate our wrapper now */
    [NSApp terminate:nil];
}

@end

int main(int argc, const char **argv)
{
    [NSApplication sharedApplication];
    [NSApp setDelegate: [MyDelegate new]];
    return NSApplicationMain(argc, argv);
}
