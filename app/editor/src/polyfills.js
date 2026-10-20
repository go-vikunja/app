// TipTap calls these; Safari has them from 15.4 and the app runs on iOS 15.
function define(target, name, value) {
  if (!(name in target)) Object.defineProperty(target, name, {value, writable: true, configurable: true})
}

define(Array.prototype, 'at', function at(index) {
  const position = Math.trunc(index) || 0
  return this[position < 0 ? this.length + position : position]
})

define(Array.prototype, 'findLast', function findLast(predicate, thisArg) {
  for (let index = this.length - 1; index >= 0; index--) {
    if (predicate.call(thisArg, this[index], index, this)) return this[index]
  }
  return undefined
})
