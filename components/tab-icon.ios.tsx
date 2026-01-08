export function tabIcon(symbol: { ios: string }) {
  return () => ({ sfSymbol: symbol?.ios });
}