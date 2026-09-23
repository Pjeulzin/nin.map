/**
 * Helper compartilhado entre a listagem pública de maestrias e a
 * tela de cadastro (admin).
 */

export function formatBranchNames(branches) {
  if (!Array.isArray(branches) || branches.length === 0) return null;
  return branches.map((b) => b.name).join(" · ");
}
