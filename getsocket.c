/*
 * getsocket
 * fetch an unused TCP port for temporary services to use
 */

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>

#include <err.h>
#include <netdb.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int
main(int argc, char *argv[]) {
	struct sockaddr_in addr;
	int sock;
	socklen_t addrlen = sizeof(addr);
	int port;

	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = inet_addr("0.0.0.0");
	addr.sin_port = htons(0);

	if ((sock = socket(AF_INET, SOCK_STREAM, 0)) == -1)
		err(1, "socket");
	bind(sock, (struct sockaddr *) &addr, sizeof(addr));
	getsockname(sock, (struct sockaddr *) &addr, &addrlen);
	port = ntohs(addr.sin_port);
	close(sock);

	printf("%d\n", port);
	return 0;
}
