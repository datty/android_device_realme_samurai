#include <stdint.h>
#include <stddef.h>

typedef struct cbs_st {
  const uint8_t *data;
  size_t len;
} CBS;

extern "C" void CBS_init(CBS *cbs, const uint8_t *data, size_t len) {
  cbs->data = data;
  cbs->len = len;
}
