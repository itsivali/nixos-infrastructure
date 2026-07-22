##############################################################################
#
# Storage tmpfs
#
# Purpose
# -------
# Enables tmpfs for /tmp with a size limit of 25% of RAM, providing fast
# ephemeral storage for temporary files.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Enable tmpfs for /tmp
# - Set /tmp size to 25% of physical RAM
#
##############################################################################

{
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "25%";
}
