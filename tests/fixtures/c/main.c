#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * A block comment
 * spanning lines
 */
struct node {
    int value;
    struct node *next;
};

enum color {
    RED,
    GREEN,
};

static const int table[] = {
    1,
    2,
    3,
};

static int insert(
    struct node **head,
    int value
) {
    struct node *n = malloc(sizeof *n);
    if (n == NULL) {
        return -1;
    }
    n->value = value;
    if (*head == NULL) {
        *head = n;
    } else if (value < (*head)->value) {
        n->next = *head;
        *head = n;
    } else {
        n->next = (*head)->next;
        (*head)->next = n;
    }
    switch (value) {
    case 0:
        puts("zero");
        break;
    default: {
        puts("other");
        break;
    }
    }
    for (int i = 0; i < value; i++) {
        printf("%d\n", i);
    }
    while (value > 0) {
        value--;
    }
    do {
        value++;
    } while (value < 3);
    printf(
        "%d %d\n",
        value,
        n->value
    );
#ifdef DEBUG
    puts("debug");
#endif
    return 0;
}

int main(void) {
    struct node *head = NULL;
    insert(&head, 1);
    return 0;
}
