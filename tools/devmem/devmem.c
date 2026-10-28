/* Minimal devmem for the frame: devmem ADDR [VALUE] (32-bit access). */
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	if (argc < 2) { fprintf(stderr, "usage: devmem ADDR [VALUE]\n"); return 1; }
	uint32_t addr = strtoul(argv[1], NULL, 0), page = addr & ~0xfffu;
	int fd = open("/dev/mem", argc > 2 ? O_RDWR | O_SYNC : O_RDONLY | O_SYNC);
	if (fd < 0) { perror("/dev/mem"); return 1; }
	volatile uint32_t *p = mmap(NULL, 4096, PROT_READ | (argc > 2 ? PROT_WRITE : 0),
				    MAP_SHARED, fd, page);
	if (p == MAP_FAILED) { perror("mmap"); return 1; }
	p += (addr - page) / 4;
	if (argc > 2)
		*p = strtoul(argv[2], NULL, 0);
	printf("0x%08x\n", *p);
	return 0;
}
