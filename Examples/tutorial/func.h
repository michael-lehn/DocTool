#ifndef TUTORIAL_FUNC_H
#define TUTORIAL_FUNC_H

int
func(int a, int b);

template <typename A, typename B>
struct IsSame;

template <bool cond, typename B>
struct RestrictTo;

template <typename T>
    typename RestrictTo<IsSame<T,long>::value,
             void>::Type
    dummy();

template <typename T>
    typename RestrictTo<IsSame<T,int>::value,
             void>::Type
    dummy();

#endif // TUTORIAL_FUNC_H
