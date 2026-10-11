// Everything shown on the homepage comes from this file. Replace every
// `TODO:` value with your own information. Components read from `DATA` and
// should not need to change.
import { Icons } from "@/components/icons";
import { House, Library } from "lucide-react";
import { Typescript } from "@/components/ui/svgs/typescript";
import { Python } from "@/components/ui/svgs/python";
import { Nodejs } from "@/components/ui/svgs/nodejs";
import { Postgresql } from "@/components/ui/svgs/postgresql";
import { Docker } from "@/components/ui/svgs/docker";
import { Astro } from "@/components/ui/svgs/astro";

export const DATA = {
  // TODO: your display name. The first word is used in the hero greeting.
  name: "Jimmy Wallace",
  // TODO: your initials, shown when the avatar image fails to load.
  initials: "JW",
  // TODO: your location and a map link, or leave the link empty.
  location: "TODO: City, ST",
  locationLink: "",
  // TODO: one-line bio shown in the hero and in meta descriptions.
  description: "TODO: One sentence about what you do.",
  // TODO: longer about section. Markdown links are supported.
  summary:
    "TODO: A short paragraph about your background and what you are working on now. You can link to sections like [work](/#work) and [education](/#education).",
  // TODO: replace public/picofme.png and public/og_image.png with your own images.
  avatarUrl: "/picofme.png",
  ogImage: "/og_image.png",
  sections: {
    about: { order: 1, enabled: true, heading: "About" },
    work: { order: 2, enabled: true, heading: "Work Experience", presentLabel: "Present" },
    education: { order: 3, enabled: true, heading: "Education" },
    skills: { order: 4, enabled: true, heading: "Skills" },
    projects: {
      order: 5,
      enabled: true,
      label: "My Projects",
      heading: "Check out my latest work",
      text: "TODO: A sentence introducing your projects.",
    },
    photos: {
      order: 6,
      enabled: false,
      heading: "Photos",
    },
    hackathons: {
      order: 7,
      enabled: false,
      label: "Hackathons",
      heading: "I like building things",
      text: "TODO: A sentence about hackathons. {count} is replaced with the number of entries.",
    },
    contact: {
      order: 8,
      enabled: true,
      label: "Contact",
      heading: "Get in Touch",
      text: "TODO: How people should reach you.",
    },
  },
  // TODO: replace the placeholder photos in public/photos/ or disable the section above.
  photos: [
    { src: "/photos/photo1.jpg", alt: "TODO: describe the photo" },
    { src: "/photos/photo2.jpg", alt: "TODO: describe the photo" },
    { src: "/photos/photo3.jpg", alt: "TODO: describe the photo" },
  ],
  // TODO: your skills. Icons live in src/components/ui/svgs/.
  skills: [
    { name: "TypeScript", icon: Typescript },
    { name: "Python", icon: Python },
    { name: "Node.js", icon: Nodejs },
    { name: "Postgres", icon: Postgresql },
    { name: "Docker", icon: Docker },
    { name: "Astro", icon: Astro },
  ],
  navbar: [
    { href: "/", icon: House, label: "Home" },
    { href: "/blog", icon: Library, label: "Blog" },
  ],
  contact: {
    // TODO: your contact details.
    email: "TODO@example.com",
    tel: "",
    social: {
      GitHub: {
        name: "GitHub",
        url: "https://github.com/jwallace145",
        icon: Icons.github,
        navbar: true,
      },
      LinkedIn: {
        name: "LinkedIn",
        // TODO: your LinkedIn profile URL.
        url: "https://www.linkedin.com/in/TODO",
        icon: Icons.linkedin,
        navbar: true,
      },
      email: {
        name: "Send Email",
        // TODO: your email address.
        url: "mailto:TODO@example.com",
        icon: Icons.email,
        navbar: false,
      },
    },
  },

  // TODO: your work history, most recent first. `end: undefined` renders as "Present".
  work: [
    {
      company: "TODO: Company",
      href: "https://example.com",
      badges: [],
      location: "TODO: City, ST",
      title: "TODO: Job Title",
      logoUrl: "",
      start: "TODO: Month Year",
      end: undefined,
      description: "TODO: What you did and the impact it had.",
    },
  ],
  // TODO: your education, most recent first.
  education: [
    {
      school: "TODO: School",
      href: "https://example.edu",
      degree: "TODO: Degree, Field",
      logoUrl: "",
      start: "TODO: Year",
      end: "TODO: Year",
    },
  ],
  // TODO: your projects. `image` or `video` is optional.
  projects: [
    {
      title: "TODO: Project",
      href: "https://github.com/jwallace145/site",
      dates: "TODO: Month Year - Present",
      active: true,
      description: "TODO: What the project is and why it matters.",
      technologies: ["Astro", "TypeScript", "Tailwind CSS", "AWS"],
      links: [
        {
          type: "Source",
          href: "https://github.com/jwallace145/site",
          icon: <Icons.github className="size-3" />,
        },
      ],
      image: "",
      video: "",
    },
  ],
  // TODO: hackathons, if any. The section is disabled above until you add some.
  hackathons: [
    {
      title: "TODO: Hackathon",
      dates: "TODO: Month Day - Day, Year",
      location: "TODO: City, ST",
      description: "TODO: What you built.",
      image: "",
      win: "",
      links: [
        {
          title: "Source",
          icon: <Icons.github className="h-4 w-4" />,
          href: "https://github.com/jwallace145",
        },
      ],
    },
  ],
} as const;
