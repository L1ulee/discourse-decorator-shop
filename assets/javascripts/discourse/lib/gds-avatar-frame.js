// Sizes an injected avatar-frame overlay to the avatar image itself, centered
// on it, so the frame stays correct regardless of the wrapping element's box.
//
// The frame span is appended to the avatar image's positioned parent, but that
// parent is not the avatar's tight box: a user card mounts it in
// <a.card-huge-avatar> and a profile mounts it in the wider
// .user-profile-avatar container, so sizing the frame to the parent (the CSS
// percentage fallback) made it oversized and offset (issue #6).
//
// Geometry is read from the image's *layout* box (offsetWidth/Height/Left/Top),
// NOT getBoundingClientRect. A user card animates in with a CSS
// `transform: scale()`; getBoundingClientRect reports the shrunk, mid-animation
// rect, which left the frame tiny and stranded in the top-left corner (the
// ResizeObserver could not rescue it — a transform does not change layout size,
// so it never fires). offsetWidth/Height ignore ancestor transforms, giving the
// avatar's true size, and the frame — being a child of the same transformed
// mount — animates in together with it. offsetLeft/Top are measured against the
// avatar's offsetParent, which the connectors force to be the mount
// (position:relative) — the frame's offsetParent too, so both share one
// coordinate system. Do NOT switch this back to getBoundingClientRect.
//
// A ResizeObserver re-runs the sizing once the avatar image actually lays out —
// lazy avatars can still have no layout size when the modifier first runs.
const OVERSCAN = 1.7;

function applyFrameGeometry(frame, avatarImage) {
  const width = avatarImage.offsetWidth;
  const height = avatarImage.offsetHeight;

  if (!width || !height) {
    return;
  }

  frame.style.left = `${avatarImage.offsetLeft + width / 2}px`;
  frame.style.top = `${avatarImage.offsetTop + height / 2}px`;
  frame.style.width = `${width * OVERSCAN}px`;
  frame.style.height = `${height * OVERSCAN}px`;
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
