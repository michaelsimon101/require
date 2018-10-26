# driver.makefile
#
# This generic makefile compiles EPICS modules (drivers, records, snl, ...)
# for all installed EPICS versions.
# Read this documentation and the inline comments carefully before
# changing anything in this file.
#
# Usage: Create a Makefile containig the line:
#        include /ioc/tool/driver.makefile
#        Optionally add variable definitions below that line.
#
# This makefile automatically finds the source file (unless overwritten with
# the SOURCES variable in your Makefile) and generates a module consisting
# of a library and .dbd file for each EPICS version and each target architecture.
# Therefore, it calls itself recursively.
#
# - First run: (see comment ## RUN 1)
#   Find out what to build
#   Iterate over all installed EPICS versions
#
# - Second run: (see comment ## RUN 2)
#   Find the sources etc.
#   Include EPICS configuration files for this ${EPICSVERSION}
#   Iterate over all target architectures (${T_A}) defined for this version
#
# - Third run: (see comment ## RUN 3)
#   Check which target architectures to build.
#   Create O.${EPICSVERSION}_${T_A} subdirectories if necessary.
#   Change to O.${EPICSVERSION}_${T_A} subdirectories.
#
# - Fourth run: (see comment ## RUN 4)
#   Compile everything.
#
# Module names are derived from the directory name (unless overwritten
# with the MODULE variable in your Makefile).
# A LIBVERSION number is generated from the latest CVS or GIT tag of the sources.
# If any file is not up-to-date in CVS/GIT, not tagged, or tagged differently from the
# other files, the version is a test version and labelled with the user name.
# The library is installed to ${EPICS_MODULES}/${MODULE}/${LIBVERSION}/lib/${T_A}/.
# A module can be loaded with  require "<module>" [,"<version>"] [,"<variable>=<substitution>, ..."]
#
# User variables (add them to your Makefile, none is required):
# MODULE
#    Name of the built module.
#    If not defined, it is derived from the directory name.
# SOURCES
#    All source files to compile. 
#    If not defined, default is all *.c *.cc *.cpp *.st *.stt in
#    the source directory (where you run make).
#    If you define this, you must list ALL sources.
# DBDS
#    All dbd files of the project.
#    If not defined, default is all *.dbd files in the source directory.
# HEADERS
#    Header files to install (e.g. to be included by other drivers)
#    If not defined, all headers are for local use only.
# EXCLUDE_VERSIONS
#    EPICS versions to skip. Usually 3.13 or 3.14
# ARCH_FILTER
#    Sub set of architectures to build for, e.g. %-ppc604

# Get the location of this file.
MAKEHOME:=$(dir $(lastword ${MAKEFILE_LIST}))
# Get the name of the Makefile that included this file.
USERMAKEFILE:=$(lastword $(filter-out $(lastword ${MAKEFILE_LIST}), ${MAKEFILE_LIST}))

# Some configuration:
DEFAULT_EPICS_VERSIONS = 3.13.9 3.13.10 3.14.8 3.14.12
BUILDCLASSES = vxWorks
EPICS_MODULES ?= /ioc/modules
MODULE_LOCATION = ${EPICS_MODULES}/$(or ${PRJ},$(error PRJ not defined))/$(or ${LIBVERSION},$(error LIBVERSION not defined))
EPICS_LOCATION = /usr/local/epics

DOCUEXT = txt html htm doc pdf ps tex dvi gif jpg png
DOCUEXT += TXT HTML HTM DOC PDF PS TEX DVI GIF JPG PNG
DOCUEXT += template db dbt subs subst substitutions script

# Override config here:
-include ${MAKEHOME}/config

# Use fancy glob to find latest versions.
SHELL = /bin/bash -O extglob

# Some shell commands:
LN = ln -s
EXISTS = test -e
NM = nm
RMDIR = rm -rf
RM = rm -f
CP = cp

# Some generated file names:
VERSIONFILE = ${PRJ}_version_${LIBVERSION}.c
REGISTRYFILE = ${PRJ}_registerRecordDeviceDriver.cpp
EXPORTFILE = ${PRJ}_exportAddress.c
SUBFUNCFILE = ${PRJ}_subRecordFunctions.dbd
DEPFILE = ${PRJ}.dep

# Clear potential environment variables.
TEMPLATES=
SOURCES=
DBDS=
HEADERS=
BASH_ENV=
ENV=

# Default target is "build" for all versions.
# Don't install anything (different from default EPICS make rules).
default: build

IGNOREFILES = .cvsignore .gitignore
%: ${IGNOREFILES}
${IGNOREFILES}:
	@echo -e "O.*\n.cvsignore\n.gitignore" > $@

# Function that removes duplicates without re-ordering (unlike sort):
define uniq
  $(eval seen :=) \
  $(foreach _,$1,$(if $(filter $_,${seen}),,$(eval seen += $_))) \
  ${seen}
endef

ifndef EPICSVERSION
## RUN 1
# In source directory

# Find out which EPICS versions to build.
INSTALLED_EPICS_VERSIONS := $(patsubst ${EPICS_LOCATION}/base-%,%,$(wildcard ${EPICS_LOCATION}/base-*[0-9]))
EPICS_VERSIONS = $(filter-out ${EXCLUDE_VERSIONS:=%},${DEFAULT_EPICS_VERSIONS})
MISSING_EPICS_VERSIONS = $(filter-out ${BUILD_EPICS_VERSIONS},${EPICS_VERSIONS})
BUILD_EPICS_VERSIONS = $(filter ${INSTALLED_EPICS_VERSIONS},${EPICS_VERSIONS})
$(foreach v,$(sort $(basename $(basename ${BUILD_EPICS_VERSIONS})) $(basename ${BUILD_EPICS_VERSIONS})),$(eval EPICS_VERSIONS_$v=$(filter $v.%,${BUILD_EPICS_VERSIONS})))

# Check only version of files needed to build the module. But which are they?
VERSIONCHECKFILES = $(filter-out /% -none-, $(wildcard *makefile* *Makefile* *.db *.template *.subs *.dbd *.cmd) ${SOURCES} ${DBDS} ${TEMPLATES} ${SCRIPTS} $($(filter SOURCES_% DBDS_%,${.VARIABLES})))
VERSIONCHECKCMD = ${MAKEHOME}/getVersion.tcl ${VERSIONDEBUGFLAG} ${VERSIONCHECKFILES}
LIBVERSION := $(or $(filter-out test,$(shell ${VERSIONCHECKCMD} 2>/dev/null)),${USER},test)
VERSIONDEBUGFLAG = $(if ${VERSIONDEBUG}, -d)

# Default module name is name of current directory.
# But in case of "src" or "snl", use parent directory instead.
# Avoid using environment variables for MODULE or PROJECT
MODULE=
PROJECT=
PRJDIR:=$(subst -,_,$(subst .,_,$(notdir $(patsubst %Lib,%,$(patsubst %/snl,%,$(patsubst %/src,%,${PWD}))))))
PRJ = $(strip $(or ${MODULE},${PROJECT},${PRJDIR}))
export PRJ

OS_CLASS_LIST = $(BUILDCLASSES)
export OS_CLASS_LIST

export ARCH_FILTER
export EXCLUDE_ARCHS
export MAKE_FIRST

# Some shell commands:
RMDIR = rm -rf
LN = ln -s
EXISTS = test -e
NM = nm
RM = rm -f
MKDIR = mkdir -p -m 775

clean::
	$(RMDIR) O.*

clean.%::
	$(RMDIR) $(wildcard O.*${@:clean.%=%}*)

uninstall:
	$(RMDIR) ${MODULE_LOCATION}

uninstall.%:
	$(RMDIR) $(wildcard ${MODULE_LOCATION}/R*${@:uninstall.%=%}*)

help:
	@echo "usage:"
	@for target in '' build '<EPICS version>' \
	install 'install.<EPICS version>' \
	uninstall 'uninstall.<EPICS version>' \
        installui uninstallui \
	clean help version; \
	do echo "  make $$target"; \
	done
	@echo "Makefile variables:(defaults) [comment]"
	@echo "  EPICS_VERSIONS   (${DEFAULT_EPICS_VERSIONS})"
	@echo "  MODULE           (${PRJ}) [from current directory name]"
	@echo "  PROJECT          [older name for MODULE]"
	@echo "  SOURCES          (*.c *.cc *.cpp *.st *.stt *.gt)"
	@echo "  DBDS             (*.dbd)"
	@echo "  HEADERS          () [only those to install]"
	@echo "  TEMPLATES        (*.template *.db *.subs) [db files]"
	@echo "  SCRIPTS          (*.cmd) [startup and other scripts]"
	@echo "  BINS             () [programs to install]"
	@echo "  QT               (qt/*) [QT user interfaces to install]"
	@echo "  EXCLUDE_VERSIONS () [versions not to build, e.g. 3.14]"
	@echo "  EXCLUDE_ARCHS    () [target architectures not to build]"
	@echo "  ARCH_FILTER      () [target architectures to build, e.g. SL6%]"
	@echo "  BUILDCLASSES     (vxWorks) [other choices: Linux]"
	@echo "  <module>_VERSION () [build against specific version of other module]"
	@echo "  IGNORE_MODULES   () [do not use header files from these modules]"

# "make version" shows the module version and why it is what it is.       
version: ${IGNOREFILES}
	@${VERSIONCHECKCMD}

debug::
	@echo "INSTALLED_EPICS_VERSIONS = ${INSTALLED_EPICS_VERSIONS}"
	@echo "BUILD_EPICS_VERSIONS = ${BUILD_EPICS_VERSIONS}"
	@echo "MISSING_EPICS_VERSIONS = ${MISSING_EPICS_VERSIONS}"
	@echo "EPICS_VERSIONS_3.13 = ${EPICS_VERSIONS_3.13}"
	@echo "EPICS_VERSIONS_3.14 = ${EPICS_VERSIONS_3.14}"
	@echo "EPICS_VERSIONS_3.15 = ${EPICS_VERSIONS_3.15}"
	@echo "EPICS_VERSIONS_3.16 = ${EPICS_VERSIONS_3.16}"
	@echo "EPICS_VERSIONS_3 = ${EPICS_VERSIONS_3}"
	@echo "EPICS_VERSIONS_7 = ${EPICS_VERSIONS_7}"
	@echo "BUILDCLASSES = ${BUILDCLASSES}"
	@echo "LIBVERSION = ${LIBVERSION}"
	@echo "VERSIONCHECKFILES = ${VERSIONCHECKFILES}"
	@echo "ARCH_FILTER = ${ARCH_FILTER}"
	@echo "PRJ = ${PRJ}"

# Loop over all EPICS versions for second run.
MAKEVERSION = ${MAKE} -f ${USERMAKEFILE} LIBVERSION=${LIBVERSION}

build install debug:: ${IGNOREFILES}
	@+for VERSION in ${BUILD_EPICS_VERSIONS}; do ${MAKEVERSION} EPICSVERSION=$$VERSION $@; done

# Handle cases where user requests a group of EPICS versions:
# make <action>.3.13 or make <action>.3.14 instead of make <action> or
# make 3.13 or make 3.14 instead of make.

define VERSIONRULES
$(1): ${IGNOREFILES}
	+for VERSION in $${EPICS_VERSIONS_$(1)}; do $${MAKEVERSION} EPICSVERSION=$$$$VERSION build; done

%.$(1): ${IGNOREFILES}
	+for VERSION in $${EPICS_VERSIONS_$(1)}; do $${MAKEVERSION} EPICSVERSION=$$$$VERSION $${@:%.$(1)=%}; done
endef
$(foreach v,$(sort $(basename $(basename ${INSTALLED_EPICS_VERSIONS})) $(basename ${INSTALLED_EPICS_VERSIONS})),$(eval $(call VERSIONRULES,$v)))

# Handle cases where user requests one specific version:
# make <action>.<version> instead of make <action> or
# make <version> instead of make
# EPICS version must be installed but need not be in EPICS_VERSIONS
${INSTALLED_EPICS_VERSIONS}: ${IGNOREFILES}
	+${MAKEVERSION} EPICSVERSION=$@ build

${INSTALLED_EPICS_VERSIONS:%=build.%}: ${IGNOREFILES}
	+${MAKEVERSION} EPICSVERSION=${@:build.%=%} build

${INSTALLED_EPICS_VERSIONS:%=install.%}: ${IGNOREFILES}
	+${MAKEVERSION} EPICSVERSION=${@:install.%=%} install

${INSTALLED_EPICS_VERSIONS:%=debug.%}: ${IGNOREFILES}
	+${MAKEVERSION} EPICSVERSION=${@:debug.%=%} debug


# Install user interfaces to global location.
# Keep a list of installed files in a hidden file for uninstall.
define INSTALL_UI_RULE
INSTALL_$(1)=$(2)
$(1)_FILES=$$(wildcard $$(or $${$(1)},$(3)))
installui: install$(1)
install$(1): uninstall$(1)
	@$$(if $${$(1)_FILES},echo "Installing $(1) user interfaces";$$(MKDIR) $${INSTALL_$(1)})
	@$$(if $${$(1)_FILES},$(CP) -v -t $${INSTALL_$(1)} $${$(1)_FILES:%='%'})
	@$$(if $${$(1)_FILES},echo "$$(patsubst %,'%',$$(notdir $${$(1)_FILES}))" > $${INSTALL_$(1)}/.$${PRJ}-$$(LIBVERSION)-$(1).txt)

uninstallui: uninstall$(1)
uninstall$(1):
	@echo "Removing old $(1) user interfaces"
	@$$(RM) -v $$(addprefix $${INSTALL_$(1)}/,$$(sort $$(patsubst %,'%',$$(notdir $${$(1)_FILES})) $$(shell cat $${INSTALL_$(1)}/.$${PRJ}-*.txt 2>/dev/null)) .$${PRJ}-*-$(1).txt)
endef

# You can add more UI rules following this pattern:
#$(eval $(call INSTALL_UI_RULE,VARIABLE,installdir,sourcedefaultlocation))
$(eval $(call INSTALL_UI_RULE,QT,${CONFIGBASE}/qt,qt/*))

else # EPICSVERSION
# EPICSVERSION defined 
# Second or third run (see T_A branch below)

EPICS_BASE=${EPICS_LOCATION}/base-${EPICSVERSION}

ifneq ($(filter 3.13.%,$(EPICSVERSION)),)

EPICS_BASETYPE=3.13
CONFIG=${EPICS_BASE}/config
export BUILD_TYPE=Vx

else # 3.14+

EPICS_BASETYPE=3.14
CONFIG=${EPICS_BASE}/configure

# There is no 64 bit support before 3.14.12 
ifneq ($(filter %_64,$(EPICS_HOST_ARCH)),)
ifeq ($(wildcard $(EPICS_BASE)/lib/$(EPICS_HOST_ARCH)),)
EPICS_HOST_ARCH:=$(patsubst %_64,%,$(EPICS_HOST_ARCH))
USR_CFLAGS_$(EPICS_HOST_ARCH) += -m32
USR_CXXFLAGS_$(EPICS_HOST_ARCH) += -m32
USR_LDFLAGS_$(EPICS_HOST_ARCH) += -m32
endif
endif

endif # 3.14+

${CONFIG}/CONFIG:
	@echo "ERROR: EPICS release ${EPICSVERSION} not installed on this host."

# Some TOP and EPICS_BASE tweeking necessary to work around release check in 3.14.10+.
EB=${EPICS_BASE}
TOP:=${EPICS_BASE}
-include ${CONFIG}/CONFIG
BASE_CPPFLAGS=
EPICS_BASE:=${EB}
COMMON_DIR = O.${EPICSVERSION}_Common
SHRLIB_VERSION=
# do not link *everything* with readline (and curses)
COMMANDLINE_LIBRARY =
# Relax (3.13) cross compilers (default is STRICT) to allow sloppier syntax.
CMPLR=STD
GCC_STD = $(GCC)
CXXCMPLR=ANSI
G++_ANSI = $(G++) -ansi
OBJ=.o

ifndef T_A
## RUN 2
# Target achitecture not yet defined
# but EPICSVERSION is already known.
# Still in source directory.

# Look for sources etc.
# Select target architectures to build.
# Export everything for third run:

AUTOSRCS := $(filter-out ~%,$(wildcard *.c *.cc *.cpp *.st *.stt *.gt))
SRCS = $(if ${SOURCES},$(filter-out -none-,${SOURCES}),${AUTOSRCS})
#SRCS += ${SOURCES_${EPICS_BASETYPE}} # added later by VAR_EXTENSIONS
#SRCS += ${SOURCES_${EPICSVERSION}}
export SRCS

DBD_SRCS = $(if ${DBDS},$(filter-out -none-,${DBDS}),$(wildcard menu*.dbd *Record.dbd) $(strip $(filter-out %Include.dbd dbCommon.dbd %Record.dbd,$(wildcard *.dbd)) ${BPTS}))
DBD_SRCS += ${DBDS_${EPICS_BASETYPE}}
DBD_SRCS += ${DBDS_${EPICSVERSION}}
export DBD_SRCS

#record dbd files given in DBDS
RECORDS = $(filter %Record, $(basename $(notdir $(SRCS))))
export RECORDS

MENUS = $(patsubst %.dbd,%.h,$(wildcard menu*.dbd))
export MENUS

BPTS = $(patsubst %.data,%.dbd,$(wildcard bpt*.data))
export BPTS

HDRS = ${HEADERS} ${RECORDS:%=${COMMON_DIR}/%.h}
HDRS += ${HEADERS_${EPICS_BASETYPE}}
HDRS += ${HEADERS_${EPICSVERSION}}
export HDRS

TEMPLS = $(if ${TEMPLATES},$(filter-out -none-,${TEMPLATES}),$(wildcard *.template *.db *.subs))
TEMPLS += ${TEMPLATES_${EPICS_BASETYPE}}
TEMPLS += ${TEMPLATES_${EPICSVERSION}}
export TEMPLS

SCR = $(if ${SCRIPTS},$(filter-out -none-,${SCRIPTS}),$(wildcard *.cmd))
SCR += ${SCRIPTS_${EPICS_BASETYPE}}
SCR += ${SCRIPTS_${EPICSVERSION}}
export SCR

DOCUDIR = .
#DOCU = $(foreach DIR,${DOCUDIR},$(wildcard ${DIR}/*README*) $(foreach EXT,${DOCUEXT}, $(wildcard ${DIR}/*.${EXT})))
export DOCU

# Loop over all target architectures for third run.
# Go to O.${T_A} subdirectory because RULES.Vx only work there:

# Filter architectures to build using EXCLUDE_ARCHS and ARCH_FILTER.
ifneq (${EPICS_BASETYPE},3.13)
CROSS_COMPILER_TARGET_ARCHS := ${EPICS_HOST_ARCH} ${CROSS_COMPILER_TARGET_ARCHS}
endif # !3.13
CROSS_COMPILER_TARGET_ARCHS := $(filter-out $(addprefix %,${EXCLUDE_ARCHS}),$(filter-out $(addsuffix %,${EXCLUDE_ARCHS}),$(if ${ARCH_FILTER},$(filter ${ARCH_FILTER},${CROSS_COMPILER_TARGET_ARCHS}),${CROSS_COMPILER_TARGET_ARCHS})))

# Create build dirs (and links) if necessary.
LINK_eldk52-e500v2 = eldk52-rt-e500v2 eldk52-xenomai-e500v2
define MAKELINKDIRS
LINKDIRS+=O.${EPICSVERSION}_$1
O.${EPICSVERSION}_$1:
	$(LN) O.${EPICSVERSION}_$2 O.${EPICSVERSION}_$1
endef 
$(foreach a,${CROSS_COMPILER_TARGET_ARCHS},$(foreach l,$(LINK_$a),$(eval $(call MAKELINKDIRS,$l,$a))))

SRCS_Linux = ${SOURCES_Linux}
SRCS_Linux += ${SOURCES_${EPICS_BASETYPE}_Linux}
SRCS_Linux += ${SOURCES_Linux_${EPICS_BASETYPE}}
export SRCS_Linux
SRCS_vxWorks = ${SOURCES_vxWorks}
SRCS_vxWorks += ${SOURCES_${EPICS_BASETYPE}_vxWorks}
SRCS_vxWorks += ${SOURCES_vxWorks_${EPICS_BASETYPE}}
export SRCS_vxWorks

install build debug:: $(MAKE_FIRST)
	@echo "MAKING EPICS VERSION R${EPICSVERSION}"

uninstall::
	$(RMDIR) ${INSTALL_REV}

debug::
	@echo "EPICS_BASE = ${EPICS_BASE}"
	@echo "EPICSVERSION = ${EPICSVERSION}" 
	@echo "EPICS_BASETYPE = ${EPICS_BASETYPE}" 
	@echo "CROSS_COMPILER_TARGET_ARCHS = ${CROSS_COMPILER_TARGET_ARCHS}"
	@echo "EXCLUDE_ARCHS = ${EXCLUDE_ARCHS}"
	@echo "LIBVERSION = ${LIBVERSION}"

install build::
# Delete old build if INSTBASE has changed and module depends on other modules.
	@+for ARCH in ${CROSS_COMPILER_TARGET_ARCHS}; do \
	    echo '$(realpath ${EPICS_MODULES})' | cmp -s O.${EPICSVERSION}_$$ARCH/INSTBASE || \
	    ( grep -qs "^[^#]" O.${EPICSVERSION}_$$ARCH/*.dep && \
	     (echo "rebuilding $$ARCH"; $(RMDIR) O.${EPICSVERSION}_$$ARCH) ) || true; \
	done

# Loop over all architectures.
install build debug::
	@+for ARCH in ${CROSS_COMPILER_TARGET_ARCHS}; do \
	    umask 002; echo MAKING ARCH $$ARCH; ${MAKE} -f ${USERMAKEFILE} T_A=$$ARCH $@; \
	done

else # T_A

ifeq ($(filter O.%,$(notdir ${CURDIR})),)
## RUN 3
# Target architecture defined.
# Still in source directory, third run.

# Add include directory of other modules to include file search path.
# By default use highest version of all other modules installed for
# current EPICSVERSION and T_A.
# The user can overwrite by defining <module>_VERSION=<version>.
# This version can be incomplete (only <major> or <major>.<minor>).
# In this case the hightest matching full version (<major>.<minor>.<patch>)
# will be selected.

# The tricky part is to sort versions numerically.
# Make can't but ls -v can.
# Only accept numerical versions (needs extended glob).
# This is slow, thus do it only once for each EPICSVERSION.

define ADD_OTHER_MODULE_INCLUDES
$(eval $(1)_VERSION := $(patsubst ${EPICS_MODULES}/$(1)/%/R${EPICSVERSION}/lib/$(T_A)/../../include,%,$(firstword $(shell ls -dvr ${EPICS_MODULES}/$(1)/+([0-9]).+([0-9]).+([0-9])/R${EPICSVERSION}/lib/$(T_A)/../../include 2>/dev/null))))
export $(1)_VERSION
OTHER_MODULE_INCLUDES += $$(addprefix -I,$$(firstword $$(shell ls -dvr ${EPICS_MODULES}/$(1)/$$($(1)_VERSION)*(.+([0-9]))/R${EPICSVERSION}/include 2>/dev/null)))
endef
$(eval $(foreach m,$(filter-out $(PRJ) $(IGNORE_MODULES),$(notdir $(wildcard ${EPICS_MODULES}/*))),$(call ADD_OTHER_MODULE_INCLUDES,$m)))
# Include path for old style modules.
OTHER_MODULE_INCLUDES += $(addprefix -I,$(wildcard ${INSTBASE}/iocBoot/R${EPICSVERSION}/include))
export OTHER_MODULE_INCLUDES

ifeq ($(filter ${OS_CLASS},${OS_CLASS_LIST}),)

install% build%: build
install build:
	@echo Skipping ${T_A} because $(if ${OS_CLASS},OS_CLASS=\"${OS_CLASS}\" is not in BUILDCLASSES=\"${BUILDCLASSES}\",it is not available for R$(EPICSVERSION).)
%:
	@true

else ifeq ($(shell which $(firstword ${CC})),)

install% build%: build
install build:
	@echo Warning: Skipping ${T_A} because cross compiler $(firstword ${CC}) is not installed.
%:
	@true

else

O.%:
	$(MKDIR) $@

ifeq ($(shell echo "${LIBVERSION}" | grep -v -E "^[0-9]+\.[0-9]+\.[0-9]+\$$"),)
install:: build
	@test ! -d ${MODULE_LOCATION}/R${EPICSVERSION}/lib/${T_A} || \
        (echo -e "Error: ${MODULE_LOCATION}/R${EPICSVERSION}/lib/${T_A} already exists.\nNote: If you really want to overwrite then uninstall first."; false)
else
install:: build
	@test ! -d ${MODULE_LOCATION}/R${EPICSVERSION}/lib/${T_A} || \
        (echo -e "Warning: Re-installing ${MODULE_LOCATION}/R${EPICSVERSION}/lib/${T_A}"; \
        $(RMDIR) ${MODULE_LOCATION}/R${EPICSVERSION}/lib/${T_A})
endif

install build debug:: O.${EPICSVERSION}_Common O.${EPICSVERSION}_${T_A}
	@${MAKE} -C O.${EPICSVERSION}_${T_A} -f ../${USERMAKEFILE} $@

endif

# Add sources for specific epics types (3.13 or 3.14) or architectures.
ARCH_PARTS = ${T_A} $(subst -, ,${T_A}) ${OS_CLASS}
VAR_EXTENSIONS = ${EPICS_BASETYPE} ${EPICSVERSION} ${ARCH_PARTS} ${ARCH_PARTS:%=${EPICS_BASETYPE}_%} ${ARCH_PARTS:%=${EPICSVERSION}_%}
export VAR_EXTENSIONS

REQ = ${REQUIRED} $(foreach x, ${VAR_EXTENSIONS}, ${REQUIRED_$x})
export REQ

HDRS +=  $(foreach x, ${VAR_EXTENSIONS}, ${HEADERS_$x})
export HDRS 

SRCS += $(foreach x, ${VAR_EXTENSIONS}, ${SOURCES_$x})
USR_LIBOBJS += ${LIBOBJS} $(foreach x,${VAR_EXTENSIONS},${LIBOBJS_$x})
export USR_LIBOBJS

BINS += $(foreach x, ${VAR_EXTENSIONS}, ${BINS_$x})
export BINS

export CFG

export IGNORE_MODULES

export API_MAY_CHANGE_BETWEEN_MINOR_VERSIONS

else # in O.*
## RUN 4
# In O.* directory.

# Add macros like USR_CFLAGS_vxWorks.
EXTENDED_VARS=INCLUDES CFLAGS CXXFLAGS CPPFLAGS CODE_CXXFLAGS LDFLAGS
$(foreach v,${EXTENDED_VARS},$(foreach x,${VAR_EXTENSIONS},$(eval $v+=$${$v_$x}) $(eval USR_$v+=$${USR_$v_$x})))
CFLAGS += ${EXTRA_CFLAGS}

COMMON_DIR_3.14 = ../O.${EPICSVERSION}_Common
COMMON_DIR_3.13 = .
COMMON_DIR = ${COMMON_DIR_${EPICS_BASETYPE}}

# Remove include directory for this module from search path.
# 3.13 and 3.14+ use different variables
INSTALL_INCLUDES := $(strip $(OTHER_MODULE_INCLUDES))
EPICS_INCLUDES =

# Manually required modules.
define ADD_MANUAL_DEPENDENCIES
$(eval $(1)_VERSION := $(or $(patsubst ${EPICS_MODULES}/$(1)/%/R${EPICSVERSION},%,$(firstword $(shell ls -dvr ${EPICS_MODULES}/$(1)/+([0-9]).+([0-9]).+([0-9])/R${EPICSVERSION} 2>/dev/null))),$(basename $(lastword $(subst -, ,$(basename $(realpath ${INSTBASE}/iocBoot/R${EPICSVERSION}/${T_A}/$(1).dep)))))))
endef
$(eval $(foreach m,${REQ},$(call ADD_MANUAL_DEPENDENCIES,$m)))

# EPICS 3.13 uses :: in some rules where 3.14 uses :
ifeq (${EPICS_BASETYPE},3.13)
INSTALLRULE=install::
BUILDRULE=build::
BASERULES=${EPICS_BASE}/config/RULES.Vx
else # 3.14+
INSTALLRULE=install:
BUILDRULE=build:
BASERULES=${EPICS_BASE}/configure/RULES
endif # 3.14+

INSTALL_REV     = ${MODULE_LOCATION}/R${EPICSVERSION}
INSTALL_BIN     = ${INSTALL_REV}/bin/$(T_A)
INSTALL_LIB     = ${INSTALL_REV}/lib/$(T_A)
INSTALL_INCLUDE = ${INSTALL_REV}/include
INSTALL_DBD     = ${INSTALL_REV}/dbd
INSTALL_DB      = ${INSTALL_REV}/db
INSTALL_CFG     = ${INSTALL_REV}/cfg
INSTALL_DOC     = ${MODULE_LOCATION}/doc
INSTALL_SCR     = ${INSTALL_REV}

#INSTALL_DOCUS = $(addprefix ${INSTALL_DOC}/${PRJ}/,$(notdir ${DOCU}))

#${INSTALL_DOC}/${PRJ}/%: %
#	@echo "Installing documentation $@"
#	$(RM) $@
#	cp $^ $@
#	chmod 444 $@
#
#${INSTALL_TEMPL}/%.template: %.template
#	@echo "Installing template file $@"
#	$(RM) $@
#	echo "#${PRJ}Lib ${LIBVERSION}" > $@
#	cat $^ >> $@
#	chmod 444 $@
#	$(SETLINKS) ${INSTALL_TEMPL} .template $(basename $(notdir $^))
#
#${INSTALL_TEMPL}/%.db: %.db
#	@echo "Installing template file $@"
#	$(RM) $@
#	$(CP) $^ >> $@
#	chmod 444 $@
#	$(SETLINKS) ${INSTALL_TEMPL} .db $(basename $(notdir $^))

# Different settings required to build library in EPICS 3.13 and 3.14+.
ifeq (${EPICS_BASETYPE},3.13) # only 3.13 from here

# Convert sources to object code, skip .a and .o here.
LIBOBJS += $(patsubst %,%.o,$(notdir $(basename $(filter-out %.o %.a,${SRCS}))))
# Add all .a and .o with absolute path.
LIBOBJS += $(filter /%.o /%.a,${SRCS})
# Add all .a and .o with relative path, but go one directory up.
LIBOBJS += $(patsubst %,../%,$(filter-out /%,$(filter %.o %.a,${SRCS})))
LIBOBJS += ${LIBRARIES:%=${INSTALL_LIB}/%Lib}
LIBOBJS += $(foreach l,${USR_LIBOBJS}, $(addprefix ../,$(filter-out /%,$l)) $(filter /%,$l))

LIBNAME = $(if $(strip ${LIBOBJS}),${PRJ}Lib,) # Must be the un-munched name.
MODULELIB = ${LIBNAME:%=%.munch}
PROD = ${MODULELIB}

# Add munched library for C++ code (does not work for Tornado 1).
#ifneq ($(filter %.cc %.cpp %.C,${SRCS}),)
#ifeq ($(filter T1-%,${T_A}),)
#PROD = ${MODULELIB}.munch
#endif # T1- T_A
#endif # .cc or .cpp found

else # Only 3.14+ from here.

LIBRARY_OBJS = $(strip ${LIBOBJS} $(foreach l,${USR_LIBOBJS},$(addprefix ../,$(filter-out /%,$l))$(filter /%,$l)))

ifeq (${OS_CLASS},vxWorks)
# Only install the munched library.
INSTALL_PROD=
MODULELIB = $(if ${LIBRARY_OBJS},${PRJ}Lib.munch,)
else
MODULELIB = $(if ${LIBRARY_OBJS},${LIB_PREFIX}${PRJ}${SHRLIB_SUFFIX},)
endif

# vxWorks
PROD_vxWorks=${MODULELIB}
LIBOBJS += $(addsuffix $(OBJ),$(notdir $(basename $(filter-out %.$(OBJ) %(LIB_SUFFIX),$(sort ${SRCS})))))
LIBOBJS += $(filter /%.$(OBJ) /%(LIB_SUFFIX),${SRCS})
LIBOBJS += ${LIBRARIES:%=${INSTALL_LIB}/%Lib}
LIBS = -L ${EPICS_BASE_LIB} ${BASELIBS:%=-l%}
LINK.cpp += ${LIBS}
PRODUCT_OBJS = ${LIBRARY_OBJS}

# Linux
LOADABLE_LIBRARY=$(if ${LIBRARY_OBJS},${PRJ},)

# Hack needed needed for 3.14.8 host arch when no Makefile exists (but only for example GNUmakefile).
ifeq (${EPICSVERSION}-${T_A},3.14.8-${EPICS_HOST_ARCH})
ifeq ($(wildcard ../Makefile),)
LOADABLE_BUILD_LIBRARY = ${LOADABLE_LIBRARY}
endif
endif

# Handle registry stuff automagically if we have a dbd file.
# See ${REGISTRYFILE} and ${EXPORTFILE} rules below.
LIBOBJS += $(if $(MODULEDBD), $(addsuffix $(OBJ),$(basename ${REGISTRYFILE} ${EXPORTFILE})))

ifdef BASE_3_16
# Suppress "'rset' is deprecated" warning for old drivers
# but not on record types where it would cause an error
ifndef USING_NEW_RSET
SUPPRESS_RSET_WARNING = -DUSE_TYPED_RSET
USR_CPPFLAGS += ${SUPPRESS_RSET_WARNING}
%Record.o: SUPPRESS_RSET_WARNING=
%Record.i: SUPPRESS_RSET_WARNING=
%Record.ii: SUPPRESS_RSET_WARNING=
%Record$(DEP): SUPPRESS_RSET_WARNING=
endif
endif

endif # Both, 3.13 and 3.14+ from here.

# For backward compatibility:
# Provide a global symbol for every version with the same
# major and equal or smaller minor version number.
# Other code using this will look for one of those symbols.
# Add an undefined symbol for the version of every used driver.
# This is done with the #define in the used headers (see below).
MAJOR_MINOR_PATCH=$(subst ., ,${LIBVERSION})
MAJOR=$(word 1,${MAJOR_MINOR_PATCH})
MINOR=$(word 2,${MAJOR_MINOR_PATCH})
PATCH=$(word 3,${MAJOR_MINOR_PATCH})
ifneq (${MINOR},)
ifdef API_MAY_CHANGE_BETWEEN_MINOR_VERSIONS
ALLMINORS = ${MINOR}
else
ALLMINORS := $(shell for ((i=0;i<=${MINOR};i++));do echo $$i;done)
endif
ifeq (${OS_CLASS}, vxWorks)
PROVIDES = ${ALLMINORS:%=--defsym __${PRJ}Lib_${MAJOR}.%=0}
endif # vxWorks
ifeq (${OS_CLASS}, Linux)
PROVIDES = ${ALLMINORS:%=-Wl,--defsym,${PRJ}Lib_${MAJOR}.%=0}
endif # Linux
endif # MINOR
LDFLAGS += ${PROVIDES} ${USR_LDFLAGS_${T_A}}

# Create and include dependency files.
# 3.13 does not make those files at all.
# 3.14.8 uses HDEPENDS to select depends mode.
# 3.14.12 uses 'HDEPENDSCFLAGS -MMD'
# 3.15 uses 'HDEPENDS_COMPFLAGS = -MM -MF $@'
# For newer compilers they are ok and ignore files in system directories.
# For old vxWorks gcc those rules ignore #include <...>,
# which may be falsey used for non-system headers.
ifneq (,$(filter T2-%,$(T_A)))
HDEPENDS = 
HDEPENDS_METHOD = COMP
HDEPENDS_COMPFLAGS = -c
CPPFLAGS += -MD
endif
-include *.d

# Need to find source dbd files relative to one dir up but generated dbd files in this dir.
DBDFILES += ${DBD_SRCS:%=../%}
DBD_PATH = $(sort $(dir ${DBDFILES}))

DBDEXPANDPATH = $(addprefix -I , ${DBD_PATH} ${EPICS_BASE}/dbd)
USR_DBDFLAGS += $(DBDEXPANDPATH)

# Search all directories where sources or headers come from, plus existing os dependend subdirectories.
SRC_INCLUDES = $(addprefix -I, $(wildcard $(foreach d,$(call uniq, $(filter-out /%,$(dir ${SRCS:%=../%} ${HDRS:%=../%}))), $d $(addprefix $d/, os/${OS_CLASS} $(POSIX_$(POSIX)) os/default))))

# Different macro name for 3.14.8.
GENERIC_SRC_INCLUDES = $(SRC_INCLUDES)

ifeq (${EPICS_BASETYPE},3.13)
# Only 3.13 from here.

# Different macro name for 3.13
USR_INCLUDES += $(SRC_INCLUDES) $(INSTALL_INCLUDES) 

else
# Only 3.14+ from here.

# Create dbd file for snl code.
DBDFILES += $(patsubst %.st,%_snl.dbd,$(notdir $(filter %.st,${SRCS})))
DBDFILES += $(patsubst %.stt,%_snl.dbd,$(notdir $(filter %.stt,${SRCS})))

# Create dbd file for GPIB code.
DBDFILES += $(patsubst %.gt,%.dbd,$(notdir $(filter %.gt,${SRCS})))

# Create dbd file with references to all subRecord functions.
# Problem: functions may be commented out. Better preprocess, but then generate headers first.
#define maksubfuncfile
#/static/ {static=1} \
#/\([\t ]*(struct)?[\t ]*(genSub|sub|aSub)Record[\t ]*\*[\t ]*\w+[\t ]*\)/ { \
#    match ($$0,/(\w+)[\t ]*\([\t ]*(struct)?[\t ]*\w+Record[\t ]*\*[\t ]*\w+[\t ]*\)/, a); \
#    n=a[1];if(!static && !f[n]){f[n]=1;print "function (" n ")"}} \
#/[;{}]/ {static=0}
#endef 
#
#$(shell awk '$(maksubfuncfile)' $(addprefix ../,$(filter %.c %.cc %.C %.cpp, $(SRCS))) > ${SUBFUNCFILE})
#DBDFILES += $(if $(shell cat ${SUBFUNCFILE}),${SUBFUNCFILE})

# snc location in 3.14+: From latest version of module seq or fall back to globally installed snc.
SNC := $(lastword $(dir ${EPICS_BASE})seq/bin/$(EPICS_HOST_ARCH)/snc $(shell ls -dv ${EPICS_MODULES}/seq/$(or $(seq_VERSION),+([0-9]).+([0-9]).+([0-9]))/R${EPICSVERSION}/bin/${EPICS_HOST_ARCH}/snc 2>/dev/null))

endif # 3.14+

ifneq ($(strip ${DBDFILES}),)
MODULEDBD=${PRJ}.dbd
endif

# If we build a library, provide a version variable.
ifneq ($(MODULELIB),)
LIBOBJS += $(addsuffix $(OBJ),$(basename ${VERSIONFILE}))
endif # MODULELIB

debug::
	@echo "BUILDCLASSES = ${BUILDCLASSES}"
	@echo "OS_CLASS = ${OS_CLASS}"
	@echo "T_A = ${T_A}"
	@echo "MODULEDBD = ${MODULEDBD}"
	@echo "RECORDS = ${RECORDS}"
	@echo "MENUS = ${MENUS}"
	@echo "BPTS = ${BPTS}"
	@echo "HDRS = ${HDRS}"
	@echo "SOURCES = ${SOURCES}" 
	@echo "SOURCES_${EPICS_BASETYPE} = ${SOURCES_${EPICS_BASETYPE}}" 
	@echo "SOURCES_${OS_CLASS} = ${SOURCES_${OS_CLASS}}" 
	@echo "SRCS = ${SRCS}" 
	@echo "LIBOBJS = ${LIBOBJS}"
	@echo "DBDS = ${DBDS}"
	@echo "DBDS_${EPICS_BASETYPE} = ${DBDS_${EPICS_BASETYPE}}"
	@echo "DBDS_${OS_CLASS} = ${DBDS_${OS_CLASS}}"
	@echo "DBD_SRCS = ${DBD_SRCS}"
	@echo "DBDFILES = ${DBDFILES}"
	@echo "TEMPLS = ${TEMPLS}"
	@echo "LIBVERSION = ${LIBVERSION}"
	@echo "MODULE_LOCATION = ${MODULE_LOCATION}"

# In 3.14.8- this is required to build %Record.h files
${BUILDRULE} ${RECORDS:%=${COMMON_DIR}/%.h}
${BUILDRULE} MODULEINFOS
${BUILDRULE} ${MODULEDBD}
${BUILDRULE} ${DEPFILE}

# In 3.15+ this is required to build %Record.h files
COMMON_INC = ${RECORDS:%=${COMMON_DIR}/%.h}

# Include default EPICS Makefiles (version dependent).
# Avoid library installation when doing 'make build'.
INSTALL_LOADABLE_SHRLIBS=
# Avoid installing *.munch to bin directory.
INSTALL_MUNCHS=
include ${BASERULES}

# Fix incompatible release rules.
RELEASE_DBDFLAGS = -I ${EPICS_BASE}/dbd
RELEASE_INCLUDES = -I${EPICS_BASE}/include 
# For EPICS 3.15:
RELEASE_INCLUDES += -I${EPICS_BASE}/include/compiler/${CMPLR_CLASS}
RELEASE_INCLUDES += -I${EPICS_BASE}/include/os/${OS_CLASS}
# Dor EPICS 3.13:
EPICS_INCLUDES += -I$(EPICS_BASE_INCLUDE) -I$(EPICS_BASE_INCLUDE)/os/$(OS_CLASS)

# Find all sources and set vpath accordingly.
$(foreach file, ${SRCS} ${TEMPLS} ${SCR}, $(eval vpath $(notdir ${file}) ../$(dir ${file})))

# Do not treat %.dbd the same way because it creates a circular dependency
# if a source dbd has the same name as the project dbd. Have to clear %.dbd and not use ../ path.
# But the %Record.h and menu%.h rules need to find their dbd files (example: asyn).
vpath %.dbd
vpath %Record.dbd ${DBD_PATH}
vpath menu%.dbd ${DBD_PATH}

# Find header files to install.
vpath %.h $(addprefix ../,$(sort $(dir $(filter-out /%,${HDRS}) ${SRCS}))) $(sort $(dir $(filter /%,${HDRS})))

PRODUCTS = ${MODULELIB} ${MODULEDBD} ${DEPFILE}
MODULEINFOS:
	@echo ${PRJ} > MODULENAME
	@echo $(realpath ${EPICS_MODULES}) > INSTBASE
	@echo ${PRODUCTS} > PRODUCTS
	@echo ${LIBVERSION} > LIBVERSION

# Build one module dbd file by expanding all source dbd files.
# We can't use dbExpand (from the default EPICS make rules)
# because it has too strict checks to be used for a loadable module.
${MODULEDBD}: ${DBDFILES}
	@echo "Expanding $@"
	${MAKEHOME}expandDBD.tcl -$(basename ${EPICSVERSION}) ${DBDEXPANDPATH} $^ > $@

# Install everything.
INSTALL_LIBS = ${MODULELIB:%=${INSTALL_LIB}/%}
INSTALL_DEPS = ${DEPFILE:%=${INSTALL_LIB}/%}
INSTALL_DBDS = ${MODULEDBD:%=${INSTALL_DBD}/%}
INSTALL_HDRS = $(addprefix ${INSTALL_INCLUDE}/,$(notdir ${HDRS}))
INSTALL_DBS  = $(addprefix ${INSTALL_DB}/,$(notdir ${TEMPLS}))
INSTALL_SCRS = $(addprefix ${INSTALL_SCR}/,$(notdir ${SCR}))
INSTALL_BINS = $(addprefix ${INSTALL_BIN}/,$(notdir ${BINS}))
INSTALL_CFGS = $(CFG:%=${INSTALL_CFG}/%)

debug::
	@echo "INSTALL_LIB = $(INSTALL_LIB)"
	@echo "INSTALL_LIBS = $(INSTALL_LIBS)"
	@echo "INSTALL_DEPS = $(INSTALL_DEPS)"
	@echo "INSTALL_DBD = $(INSTALL_DBD)"
	@echo "INSTALL_DBDS = $(INSTALL_DBDS)"
	@echo "INSTALL_INCLUDE = $(INSTALL_INCLUDE)"
	@echo "INSTALL_HDRS = $(INSTALL_HDRS)"
	@echo "INSTALL_DB = $(INSTALL_DB)"
	@echo "INSTALL_DBS = $(INSTALL_DBS)"
	@echo "INSTALL_SCR = $(INSTALL_SCR)"
	@echo "INSTALL_SCRS = $(INSTALL_SCRS)"
	@echo "INSTALL_CFG = $(INSTALL_CFG)"
	@echo "INSTALL_CFGS = $(INSTALL_CFGS)"
	@echo "INSTALL_BIN = $(INSTALL_BIN)"
	@echo "INSTALL_BINS = $(INSTALL_BINS)"

INSTALLS += ${INSTALL_CFGS} ${INSTALL_SCRS} ${INSTALL_HDRS} ${INSTALL_DBDS} ${INSTALL_DBS} ${INSTALL_LIBS} ${INSTALL_BINS} ${INSTALL_DEPS}

ifdef API_MAY_CHANGE_BETWEEN_MINOR_VERSIONS
INSTALLS += ${EPICS_MODULES}/${PRJ}/use_exact_minor_version
%/use_exact_minor_version:
	touch $@
endif

${INSTALLRULE} ${INSTALLS}

${INSTALL_DBDS}: $(notdir ${INSTALL_DBDS})
	@echo "Installing module dbd file $@"
	$(INSTALL) -d -m444 $< $(@D)

${INSTALL_LIBS}: $(notdir ${INSTALL_LIBS})
	@echo "Installing module library $@"
	$(INSTALL) -d -m555 $< $(@D)

${INSTALL_DEPS}: $(notdir ${INSTALL_DEPS})
	@echo "Installing module dependency file $@"
	$(INSTALL) -d -m444 $< $(@D)

# Fix templates for older EPICS versions:
# Remove 'alias' for EPICS <= 3.14.10
# and 'info' and macro defaults for EPICS 3.13.
# Make use of differences in defined variables.
ifeq ($(DEP),.d)
# 3.14.10+
${INSTALL_DBS}: $(notdir ${INSTALL_DBS})
	@echo "Installing module template files $^ to $(@D)"
	$(INSTALL) -d -m444 $^ $(@D)
else ifeq (${EPICS_BASETYPE},3.13)
# 3.13
${INSTALL_DBS}: $(notdir ${INSTALL_DBS})
	@echo "Installing module template files $^ to $(@D)"
	mkdir -p -m 775 $(@D)
	for i in $^; do sed -r 's/\$$\{([^={]*)=[^}]*\}/$${\1}/g;s/\$$\(([^=(]*)=[^)]*\)/$$(\1)/g;s/(^|\))[ \t]*(alias|info)[ \t]*\(/#&/g' $$i > $(@D)/$$(basename $$i); done
else
# 3.14.9-
${INSTALL_DBS}: $(notdir ${INSTALL_DBS})
	@echo "Installing module template files $^ to $(@D)"
	mkdir -p -m 775 $(@D)
	for i in $^; do sed -r 's/(^|\))[ \t]*alias[ \t]*/#&/g' $$i > $(@D)/$$(basename $$i); done
endif

${INSTALL_SCRS}: $(notdir ${SCR})
	@echo "Installing scripts $^ to $(@D)"
	$(INSTALL) -d -m555 $^ $(@D)

${INSTALL_CFGS}: ${CFGS}
	@echo "Installing configuration files $^ to $(@D)"
	$(INSTALL) -d -m444 $^ $(@D)

${INSTALL_BINS}: $(addprefix ../,$(filter-out /%,${BINS})) $(filter /%,${BINS})
	@echo "Installing binaries $^ to $(@D)"
	$(INSTALL) -d -m555 $^ $(@D)

# Create SNL code from st/stt file.
# (RULES.Vx only allows ../%.st, 3.14 has no .st rules at all.)
# Important to have %.o: %.st and %.o: %.stt rule before %.o: %.c rule!
# Preprocess in any case because docu and implemented EPICS rules mismatch here.

CPPSNCFLAGS1  = $(filter -D%, ${OP_SYS_CFLAGS})
CPPSNCFLAGS1 += $(filter-out ${OP_SYS_INCLUDE_CPPFLAGS} ,${CPPFLAGS}) ${CPPSNCFLAGS}
CPPSNCFLAGS1 += -I $(dir $(SNC))../../include
SNCFLAGS += -r

%$(OBJ) %_snl.dbd: %.st
	@echo "Preprocessing $(<F)"
	$(RM) $(*F).i
	$(CPP) ${CPPSNCFLAGS1} $< > $(*F).i
	@echo "Converting $(*F).i"
	$(RM) $@
	$(SNC) $(TARGET_SNCFLAGS) $(SNCFLAGS) $(*F).i
	@echo "Compiling $(*F).c"
	$(RM) $@
	$(COMPILE.c) ${SNC_CFLAGS} $(*F).c
ifneq (${EPICS_BASETYPE},3.13)
	@echo "Building $(*F)_snl.dbd"
	awk -F [\(\)]  '/epicsExportRegistrar/ { print "registrar (" $$2 ")"}' $(*F).c > $(*F)_snl.dbd
endif

%$(OBJ) %_snl.dbd: %.stt
	@echo "Preprocessing $(<F)"
	$(RM) $(*F).i
	$(CPP) ${CPPSNCFLAGS1} $< > $(*F).i
	@echo "Converting $(*F).i"
	$(RM) $@
	$(SNC) $(TARGET_SNCFLAGS) $(SNCFLAGS) $(*F).i
	@echo "Compiling $(*F).c"
	$(RM) $@
	$(COMPILE.c) ${SNC_CFLAGS} $(*F).c
ifneq (${EPICS_BASETYPE},3.13)
	@echo "Building $(*F)_snl.dbd"
	awk -F [\(\)]  '/epicsExportRegistrar/ { print "registrar(" $$2 ")"}' $(*F).c > $(*F)_snl.dbd
endif

# Create GPIB code from *.gt file.
%.c %.dbd %.list: %.gt
	@echo "Converting $*.gt"
	${LN} $< $(*F).gt
	gdc $(*F).gt

# The original EPICS munching rules do not really work well.
# Call the native vxWorks munch program.
MUNCH_5=tclsh $(VX_DIR)/host/src/hutils/munch.tcl
MUNCH_6=tclsh $(VX_DIR)/host/resource/hutils/tcl/munch.tcl
MUNCH_=$(MUNCH_5)
# VXWORKS_MAJOR_VERSION exsists since EPICS 3.14.12 or so.
MUNCH=$(MUNCH_$(VXWORKS_MAJOR_VERSION))
%.munch: CMPLR=TRAD
%.munch: %
	@echo Munching $<
	$(RM) ctct.o ctdt.c
	$(NM) $< | $(MUNCH) > ctdt.c
	$(COMPILE.c) ctdt.c
	$(LINK.c) $@ $< ctdt.o

%_ctdt.c : %.nm
	@echo Munching $*
	@$(RM) $@
	$(MUNCH) < $< > $@ 

${VERSIONFILE}:
	echo "char _${PRJ}LibRelease[] = \"${LIBVERSION}\";" >> $@

# EPICS R3.14+:
# Create file to fill registry from dbd file.
${REGISTRYFILE}: ${MODULEDBD}
	$(RM) $@ temp.cpp
	$(PERL) $(EPICS_BASE_HOST_BIN)/registerRecordDeviceDriver.pl $< $(basename $@) | grep -v iocshRegisterCommon > temp.cpp
	$(MV) temp.cpp $@

# 3.14.12 complains if this rule is not overwritten
./%Include.dbd:

# For 3.13 code used with 3.14+:
# Add missing epicsExportAddress() calls for registry.

define makexportfile
BEGIN { print "/* This is a generated file. Do not modify! */"; \
	print "#include <drvSup.h>"; \
	print "#include <devSup.h>"; \
	print "#include <recSup.h>"; \
	print "#include <registryFunction.h>"; \
	print "#include <epicsExport.h>"; \
	print "/* These are the RegisterFunction and ExportAddress calls missing for 3.14 compatible code. */"; \
      } \
/ U pvar_func_register_func_/ {name=substr($$2,25); func_missing[name]=1; next;} \
/ [A-Z] pvar_func_register_func_/ {name=substr($$3,25); func_found[name]=1; next;} \
/ U pvar_func_/ {name=substr($$2,11); reg_missing[name]=1; next;} \
/ [A-Z] pvar_func_/ {name=substr($$3,11); reg_found[name]=1; next;} \
/ U pvar_/ {i=index(substr($$2,6),"_"); type=substr($$2,6,i-1); name=substr($$2,i+6); var_missing[name]=type; next;} \
/ [A-Z] pvar_/ {i=index(substr($$3,6),"_"); name=substr($$3,i+6); var_found[name]=1; next;} \
END {for (name in func_missing) if (!func_found[name]) { \
	print "void " name "();"; \
	print "epicsRegisterFunction(" name ");"} \
     for (name in reg_missing) if (!reg_found[name]) { \
	print "extern REGISTRYFUNCTION " name ";"; \
	print "epicsExportRegistrar(" name ");"} \
     for (name in var_missing) if (!var_found[name]) { \
        type = var_missing[name]; \
	print "extern " type " " name ";"; \
	print "epicsExportAddress(" type ", " name ");"} \
    }
endef
 
CORELIB = ${CORELIB_${OS_CLASS}}
CORELIB_vxWorks = $(firstword $(wildcard ${EPICS_BASE}/bin/${T_A}/softIoc.munch ${EPICS_BASE}/bin/${T_A}/iocCoreLibrary.munch))
 
ifeq (${OS_CLASS},vxWorks)
SHARED_LIBRARIES=NO
endif
LSUFFIX_YES=$(SHRLIB_SUFFIX)
LSUFFIX_NO=$(LIB_SUFFIX)
LSUFFIX=$(LSUFFIX_$(SHARED_LIBRARIES))
 
${EXPORTFILE}: $(filter-out $(basename ${EXPORTFILE})$(OBJ),${LIBOBJS})
	$(RM) $@
	$(NM) $^ ${BASELIBS:%=${EPICS_BASE}/lib/${T_A}/${LIB_PREFIX}%$(LSUFFIX)} ${CORELIB} | awk '$(makexportfile)' > $@

# Create dependency file for recursive requires.
${DEPFILE}: ${LIBOBJS} $(USERMAKEFILE)
	@echo "Collecting dependencies"
	$(RM) $@
	@echo "# Generated file. Do not edit." > $@
	# Check dependencies on other module headers.
	cat *.d 2>/dev/null | sed 's/ /\n/g' | sed -n 's%${EPICS_MODULES}/*\([^/]*\)/\([0-9]*\.[0-9]*\)\.[0-9]*/.*%\1 \2%p;s%$(EPICS_MODULES)/*\([^/]*\)/\([^/]*\)/.*%\1 \2%p'| sort -u >> $@
ifneq ($(strip ${REQ}),)
	# Manully added dependencies: ${REQ}
	@$(foreach m,${REQ},echo "$m $(or ${$m_VERSION},$(and $(wildcard ${EPICS_MODULES}/$m),$(error REQUIRED module $m has no numbered version. Set $m_VERSION)),$(warning REQUIRED module $m not found for ${T_A}.))" >> $@;)
endif
ifdef OLD_INCLUDE
	# Check dependencies on old style driver headers.
	@${MAKEHOME}/getPrerequisites.tcl -dep ${OLD_INCLUDE} | grep -vw -e ${PRJ} -e ^$$ >> $@ && echo "Warning: dependency on old style driver"; true;
endif

# Remove MakefileInclude after we are done because it interfers with our way to build.
$(BUILDRULE)
	$(RM) MakefileInclude

endif # In O.* directory
endif # T_A defined
endif # EPICSVERSION defined
