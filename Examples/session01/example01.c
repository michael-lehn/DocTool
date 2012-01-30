/// Include file _stdio.h_ for later using *printf*
#include <stdio.h>

/// *max* function for arguments of type *double*
double
max(double x, double y)
{
    if (x>y) {
        return x;
    } else {
        return y;
    }
}

/// Function *main* returns the maximum of its two arguments.  Note that the
/// functions expects arguments of type *double*.
int
main()
{
    printf("%f", max(2.2, 2.5));
    return 0;
}
