#include <stdio.h>
#include <unistd.h>

#define UNITS 8

void main() {
   int cycle = 0;

   int line = -1;

   int csync = -1;
   int irq = -1;
   int blue = -1;

   int t_csync = 0;
   int t_irq = 0;
   int t_blue = 0;

   int start = 0;
   int odd_field = -1;
   char ch;
   while(read(STDIN_FILENO, &ch, 1) > 0) {
      // Look for change in csync
      if ((ch & 1) != csync) {
         csync = ch & 1;
         if (!csync) {
            int high_duration = cycle - t_csync;
            int new_field = -1;
            if (high_duration < 16 * 25) {
               new_field = 0;
            } else if (high_duration < 16 * 50) {
               new_field = 1;
            }
            if (new_field >= 0 && odd_field != new_field) {
               odd_field = new_field;
               printf("%s VSync %d\n", odd_field ? "Odd" : "Even", (cycle - start) / UNITS);
            }
            if (line >= 0) {
               line++;
            }
            //printf("# %d %f\n", cycle - t_csync, (double) (cycle - t_csync) / 16.0);
         }
         t_csync = cycle;
      }
      // Look for change in irq
      if ((ch & 2) != irq) {
         irq = ch & 2;
         if (!irq) {
            printf("irq at %d line %d\n", (cycle - start) / UNITS, line);
         }
         t_irq = cycle;
      }
      // Look for change in blue
      if ((ch & 4) != blue) {
         blue = ch & 4;
         if (!blue) {
            // printf("# %d %f\n", cycle - t_blue, (double) (cycle - t_blue) / 16.0);
         }
         if (blue && (cycle - t_blue > 50000)) {
            line = 0;
            if (odd_field == 1) {
               if (start) {
                  printf("frame length: %d (%d lines)\n\n",
                         (cycle - start) / UNITS,
                         (cycle - start) / 1024);
               }
               start = cycle;
            }
         }
         t_blue = cycle;
      }
      cycle++;
   }
}
