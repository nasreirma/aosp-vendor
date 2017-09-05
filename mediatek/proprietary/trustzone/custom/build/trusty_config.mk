include $(TRUSTZONE_CUSTOM_BUILD_PATH)/common_config.mk

ifeq ($(TARGET_BUILD_VARIANT),eng)
  TRUSTY_INSTALL_MODE ?= Debug
else
  TRUSTY_INSTALL_MODE ?= Release
endif
ifeq ($(TRUSTY_INSTALL_MODE),Debug)
  TRUSTY_INSTALL_MODE_LC := debug
else
  TRUSTY_INSTALL_MODE_LC := release
endif

export TRUSTY_ADDITIONAL_DEPENDENCIES := $(abspath $(TRUSTZONE_PROJECT_MAKEFILE) $(TRUSTZONE_CUSTOM_BUILD_PATH)/common_config.mk $(TRUSTZONE_CUSTOM_BUILD_PATH)/trusty_config.mk)
TRUSTY_RAW_IMAGE_NAME := $(TARGET_OUT_INTERMEDIATES)/TRUSTY_OBJ/build-$(TRUSTY_PROJECT)/lk.bin
TRUSTY_TEMP_PADDING_FILE := $(TRUSTZONE_IMAGE_OUTPUT_PATH)/bin/$(ARCH_MTK_PLATFORM)_trusty_$(TRUSTY_INSTALL_MODE_LC)_pad.txt
TRUSTY_TEMP_CFG_FILE := $(TRUSTZONE_IMAGE_OUTPUT_PATH)/bin/img_hdr_trusty.cfg
TRUSTY_SIGNED_IMAGE_NAME := $(TRUSTZONE_IMAGE_OUTPUT_PATH)/bin/$(ARCH_MTK_PLATFORM)_trusty_$(TRUSTY_INSTALL_MODE_LC)_signed.img
TRUSTY_PADDING_IMAGE_NAME := $(TRUSTZONE_IMAGE_OUTPUT_PATH)/bin/$(ARCH_MTK_PLATFORM)_trusty_$(TRUSTY_INSTALL_MODE_LC)_pad.img
TRUSTY_COMP_IMAGE_NAME := $(TRUSTZONE_IMAGE_OUTPUT_PATH)/bin/$(ARCH_MTK_PLATFORM)_trusty.img

$(TRUSTY_TEMP_PADDING_FILE): ALIGNMENT=512
$(TRUSTY_TEMP_PADDING_FILE): MKIMAGE_HDR_SIZE=512
$(TRUSTY_TEMP_PADDING_FILE): RSA_SIGN_HDR_SIZE=576
$(TRUSTY_TEMP_PADDING_FILE): $(TRUSTY_RAW_IMAGE_NAME) $(TRUSTY_ADDITIONAL_DEPENDENCIES)
	@echo Trusty build: $@
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -f $@
	$(hide) FILE_SIZE=$$(($$(wc -c < "$(TRUSTY_RAW_IMAGE_NAME)")+$(MKIMAGE_HDR_SIZE)+$(RSA_SIGN_HDR_SIZE)));\
	REMAINDER=$$(($${FILE_SIZE} % $(ALIGNMENT)));\
	if [ $${REMAINDER} -ne 0 ]; then dd if=/dev/zero of=$@ bs=$$(($(ALIGNMENT)-$${REMAINDER})) count=1; else touch $@; fi

$(TRUSTY_TEMP_CFG_FILE): $(TEE_DRAM_SIZE_CFG) $(TRUSTY_ADDITIONAL_DEPENDENCIES)
	@echo Trusty build: $@
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -f $@
	@echo "LOAD_MODE = 0" > $@
	@echo "NAME = tee" >> $@
	@echo "LOAD_ADDR =" $(TEE_TOTAL_DRAM_SIZE) >> $@

$(TRUSTY_PADDING_IMAGE_NAME): $(TRUSTY_RAW_IMAGE_NAME) $(TRUSTY_TEMP_PADDING_FILE) $(TRUSTY_ADDITIONAL_DEPENDENCIES)
	@echo Trusty build: $@
	$(hide) mkdir -p $(dir $@)
	$(hide) cat $(TRUSTY_RAW_IMAGE_NAME) $(TRUSTY_TEMP_PADDING_FILE) > $@

$(TRUSTY_SIGNED_IMAGE_NAME): ALIGNMENT=512
$(TRUSTY_SIGNED_IMAGE_NAME): $(TRUSTY_PADDING_IMAGE_NAME) $(TRUSTZONE_SIGN_TOOL) $(TRUSTZONE_IMG_PROTECT_CFG) $(TEE_DRAM_SIZE_CFG) $(TRUSTY_ADDITIONAL_DEPENDENCIES)
	@echo Trusty build: $@
	$(hide) mkdir -p $(dir $@)
	$(hide) $(TRUSTZONE_SIGN_TOOL) $(TRUSTZONE_IMG_PROTECT_CFG) $(TRUSTY_PADDING_IMAGE_NAME) $@ $(TEE_DRAM_SIZE)
	$(hide) FILE_SIZE=$$(wc -c < "$(TRUSTY_SIGNED_IMAGE_NAME)");REMAINDER=$$(($${FILE_SIZE} % $(ALIGNMENT)));\
	if [ $${REMAINDER} -ne 0 ]; then echo "[ERROR] File $@ size $${FILE_SIZE} is not $(ALIGNMENT) bytes aligned";exit 1; fi

$(TRUSTY_COMP_IMAGE_NAME): ALIGNMENT=512
$(TRUSTY_COMP_IMAGE_NAME): $(TRUSTY_SIGNED_IMAGE_NAME) $(MTK_MKIMAGE_TOOL) $(TRUSTY_TEMP_CFG_FILE)  $(TRUSTY_ADDITIONAL_DEPENDENCIES)
	@echo Trusty build: $@
	$(hide) mkdir -p $(dir $@)
	$(hide) $(MTK_MKIMAGE_TOOL) $(TRUSTY_SIGNED_IMAGE_NAME) $(TRUSTY_TEMP_CFG_FILE) > $@
	$(hide) FILE_SIZE=$$(wc -c < "$(TRUSTY_COMP_IMAGE_NAME)");REMAINDER=$$(($${FILE_SIZE} % $(ALIGNMENT)));\
	if [ $${REMAINDER} -ne 0 ]; then echo "[ERROR] File $@ size $${FILE_SIZE} is not $(ALIGNMENT) bytes aligned";exit 1; fi
