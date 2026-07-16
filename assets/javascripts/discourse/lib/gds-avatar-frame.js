// Sizes an injected avatar-frame overlay to the avatar image itself, centered
// on it, so the frame stays correct regardless of the wrapping element's box.
//
// The frame span is appended to the avatar image's positioned parent, but that
// parent is not always the avatar's tight box: in a user card it is the
// <a.card-huge-avatar> link (smaller than the avatar -> frame too small), and
// in a profile/message it is a wider .user-profile-avatar container (-> frame
// oversized and offset). Anchoring to the image's own offset box fixes both
// (issue #6). Falls back to the CSS percentage sizing if layout is unavailable.
const OVERSCAN = 1.3;

export function sizeAvatarFrame(frame, avatarImage) {
  const width = avatarImage.offsetWidth || avatarImage.width || 0;
  const height = avatarImage.offsetHeight || avatarImage.height || 0;

  if (!width || !height) {
    return;
  }

  frame.style.left = `${avatarImage.offsetLeft + width / 2}px`;
  frame.style.top = `${avatarImage.offsetTop + height / 2}px`;
  frame.style.width = `${width * OVERSCAN}px`;
  frame.style.height = `${height * OVERSCAN}px`;
  frame.style.transform = "translate(-50%, -50%)";
}
