#include <tutorial/func.h>

int
func(int a, int b)
{
    return a+b;
}

template <typename T>
typename RestrictTo<IsSame<T,long>::value,
         void>::Type
dummy()
{
}

template <typename T>
typename RestrictTo<IsSame<T,int>::value,
         void>::Type
dummy()
{
}

