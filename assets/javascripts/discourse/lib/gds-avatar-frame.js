// Sizes an injected avatar-frame overlay to the avatar image itself, centered
// on it, so the frame stays correct regardless of the wrapping element's box.
//
// The frame span is appended to the avatar image's positioned parent, but that
// parent is not the avatar's tight box: a user card mounts it in
// <a.card-huge-avatar> and a profile/message mounts it in the wider
// .user-profile-avatar container, so sizing the frame to the parent (the old
// CSS 120% fallback) made it oversized and offset (issue #6).
//
// getBoundingClientRect is used for accurate rendered geometry (offsetLeft/Top
// misbehaves across borders and offsetParent quirks), and a ResizeObserver
// re-runs the sizing once the avatar image actually lays out — animated/lazy
// avatars often have no size at the moment the modifier runs.
const OVERSCAN = 1.3;

function applyFrameGeometry(frame, avatarImage) {
  const mount = frame.offsetParent;

  if (!mount) {
    return;
  }

  const image = avatarImage.getBoundingClientRect();

  if (!image.width || !image.height) {
    return;
  }

  const parent = mount.getBoundingClientRect();

  frame.style.left = `${image.left - parent.left + image.width / 2}px`;
  frame.style.top = `${image.top - parent.top + image.height / 2}px`;
  frame.style.width = `${image.width * OVERSCAN}px`;
  frame.style.height = `${image.height * OVERSCAN}px`;
  frame.style.transform = "translate(-50%, -50%)";
}

// Returns a cleanup function that stops observing.
export function sizeAvatarFrame(frame, avatarImage) {
  applyFrameGeometry(frame, avatarImage);

  if (typeof ResizeObserver === "undefined") {
    return () => {};
  }

  const observer = new ResizeObserver(() =>
    applyFrameGeometry(frame, avatarImage)
  );
  observer.observe(avatarImage);
  return () => observer.disconnect();
}
