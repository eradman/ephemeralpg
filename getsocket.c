/*
 * Copyright (c) 2015 Eric Radman <ericshane@eradman.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <sys/socket.h>

#include <netdb.h>
#include <stdio.h>
#include <string.h>

/*
 * getport
 * fetch an unused TCP port for temporary services to use
 */

main(int argc, char *argv[]) {
	struct sockaddr_in addr;
	int sock;
	socklen_t len = sizeof(addr);

	sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, 0, 0);
	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_port = htons(0);
	addr.sin_addr.s_addr = htonl(inet_addr("0.0.0.0"));
	bind(sock, (struct sockaddr*) &addr, sizeof(addr));
	getsockname(sock, (struct sockaddr*) &addr, &len);

	printf("%d\n", addr.sin_port);
	return 0;
}
